// 날씨 게임 학생용 서버 함수. 학생은 계정이 없으므로 입장 때 받은 세션 토큰으로만 확인한다.
//   action "sets"   : (앱 초대 링크 전용) 학생이 고를 수 있는 공개된 미션 세트 목록
//   action "set"    : 미션(세트 내용) 가져오기. 앱 초대 링크로 들어온 학생은 공개된 세트를 골라 가져올 수 있다
//   action "submit" : 점수 저장 (같은 rid는 한 번만)
//   action "rank"   : 같은 교사 학생들의 순위표 (scope: class | grade | all)
import { adminClient, hmacKey, json, preflight } from "../_shared/common.ts";
import { findSession, touchSession, type StudentSession } from "../_shared/student-session.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const GUESS_CONTENT_ID = "00000000-0000-4000-8000-00000000cafe"; // '날씨 맞추기' 고정 id
export const APP_CONTENT_ID = "00000000-0000-4000-8000-00000000a99a";   // '앱 전체' 초대 링크의 고정 id (학생이 들어와서 활동을 고른다)
const isUuid = (v: unknown): v is string => typeof v === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
const int = (v: unknown, lo: number, hi: number): number | null => {
  const n = Number(v);
  return Number.isInteger(n) && n >= lo && n <= hi ? n : null;
};

// 이 활동의 링크가 있거나, 같은 교사의 '앱 전체' 링크가 사용 가능하면 참여할 수 있다
async function usableLink(admin: SupabaseClient, s: StudentSession, contentId: string): Promise<boolean> {
  const { data } = await admin.from("share_links").select("expires_at")
    .eq("teacher_id", s.teacher_id).eq("app_slug", "weather").in("content_id", [contentId, APP_CONTENT_ID]).eq("is_active", true);
  return (data ?? []).some((l) => !l.expires_at || new Date(l.expires_at).getTime() > Date.now());
}

Deno.serve(async (req: Request) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json(req, { error: "method_not_allowed" }, 405);
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return json(req, { error: "bad_request" }, 400); }
  const action = b?.action;
  if (action !== "set" && action !== "sets" && action !== "submit" && action !== "rank") return json(req, { error: "bad_request" }, 400);
  if (!isUuid(b.content_id)) return json(req, { error: "bad_request" }, 400);
  const contentId = b.content_id.toLowerCase();

  const admin = adminClient();
  const s = await findSession(admin, await hmacKey(), b.session_token);
  if (!s) return json(req, { error: "session_expired", message: "입장 시간이 끝났어요. 다시 들어와 주세요." }, 401);
  if (!(await usableLink(admin, s, contentId))) {
    return json(req, { error: "not_allowed", message: "이 활동은 지금 참여할 수 없어요. 선생님께 확인해 주세요." }, 403);
  }
  await touchSession(admin, s);
  const isGuess = contentId === GUESS_CONTENT_ID;

  if (action === "sets") {
    if (contentId !== APP_CONTENT_ID) return json(req, { error: "bad_request" }, 400);
    // 앱 전체 링크로 들어온 학생에게만 보여 준다(링크가 없는 교사의 학생에게는 위에서 이미 막힌다)
    const { data, error } = await admin.from("weather_mission_sets").select("id, name, missions")
      .eq("is_published", true).order("updated_at", { ascending: false }).limit(100);
    if (error) return json(req, { error: "load_failed", message: "미션 목록을 불러오지 못했어요." }, 500);
    // deno-lint-ignore no-explicit-any
    return json(req, { sets: (data ?? []).map((r: any) => ({ id: r.id, name: r.name, count: Array.isArray(r.missions) ? r.missions.length : 0 })) });
  }

  if (action === "set") {
    if (contentId === APP_CONTENT_ID) return json(req, { mode: "app", name: "기상요소로 날씨 만들기" });
    if (isGuess) return json(req, { mode: "guess", name: "날씨 맞추기" });
    const { data } = await admin.from("weather_mission_sets").select("name, missions").eq("id", contentId).eq("is_published", true).maybeSingle();
    if (!data) return json(req, { error: "not_found", message: "미션을 찾지 못했어요. 선생님께 확인해 주세요." }, 404);
    return json(req, { mode: "mission", name: data.name, missions: data.missions });
  }

  if (action === "submit") {
    if (!isUuid(b.rid)) return json(req, { error: "bad_request" }, 400);
    const stages = int(b.stages, 1, 100), max = int(b.max_score, 1, 1000), score = int(b.score, 0, 1000);
    const dur = b.duration_sec == null ? null : int(b.duration_sec, 0, 86400);
    if (stages == null || max == null || score == null || score > max || (b.duration_sec != null && dur == null)) {
      return json(req, { error: "bad_request" }, 400);
    }
    let setName = "날씨 맞추기";
    if (!isGuess) {
      const { data } = await admin.from("weather_mission_sets").select("name, missions").eq("id", contentId).eq("is_published", true).maybeSingle();
      if (!data) return json(req, { error: "not_found" }, 404);
      setName = data.name;
      // 세트 쪽 값으로 점수 상한을 확인한다: 문제 수는 한 번에 최대 15개, 단계당 10점
      if (stages > Math.min(15, (data.missions as unknown[]).length) || max !== stages * 10) return json(req, { error: "bad_request" }, 400);
    }
    const detail = Array.isArray(b.detail) && b.detail.length <= 100 ? b.detail : null;
    const { error } = await admin.from("weather_records").upsert({
      rid: b.rid, teacher_id: s.teacher_id, student_id: s.student_id, content_id: contentId,
      mode: isGuess ? "guess" : "mission", set_name: setName, score, max_score: max, stages, duration_sec: dur, detail,
    }, { onConflict: "student_id,rid", ignoreDuplicates: true });
    if (error) return json(req, { error: "save_failed", message: "기록을 저장하지 못했어요." }, 500);
    return json(req, { ok: true });
  }

  // rank: 학생마다 가장 좋은 기록 하나. 같은 교사의 학생끼리만 보이며 학생 id는 내보내지 않는다
  const scope = b.scope === "grade" || b.scope === "all" ? b.scope : "class";
  const { data, error } = await admin.from("weather_records")
    .select("student_id, score, max_score, duration_sec, created_at, student:students(name, grade, class_no)")
    .eq("teacher_id", s.teacher_id).eq("content_id", contentId)
    .order("score", { ascending: false }).order("duration_sec", { ascending: true, nullsFirst: false }).order("created_at", { ascending: true })
    .limit(1000);
  if (error) return json(req, { error: "load_failed", message: "순위표를 불러오지 못했어요." }, 500);
  const seen = new Set<string>();
  // deno-lint-ignore no-explicit-any
  const rows = (data ?? []).filter((r: any) => !seen.has(r.student_id) && !!seen.add(r.student_id))
    // deno-lint-ignore no-explicit-any
    .filter((r: any) => r.student && (scope === "all" || (r.student.grade === s.student.grade && (scope === "grade" || r.student.class_no === s.student.class_no))))
    .slice(0, 200)
    // deno-lint-ignore no-explicit-any
    .map((r: any) => ({ name: r.student.name, grade: r.student.grade, class_no: r.student.class_no, score: r.score, max_score: r.max_score,
      duration_sec: r.duration_sec, created_at: r.created_at, mine: r.student_id === s.student_id }));
  return json(req, { rows });
});
