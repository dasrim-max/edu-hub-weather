-- 7단계 앱 통합: 날씨 게임(기상요소로 날씨 만들기)
-- 원칙: 미션 세트는 관리자만 만들고, 교사는 공개된 세트를 골라 링크·QR로 나눠 준다.
--       기록은 학생 세션을 확인하는 서버 함수(weather-record)만 쓰고, 교사는 자기 학생 기록만 읽고 지운다.
--       학생은 DB를 직접 읽거나 쓰지 않는다. 옛 weather_records(menticlone 프로젝트)는 옮기지 않는다.

create table public.weather_mission_sets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 30),
  missions jsonb not null check (jsonb_typeof(missions) = 'array' and jsonb_array_length(missions) between 1 and 60),
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.weather_records (
  id uuid primary key default gen_random_uuid(),
  rid uuid not null,                                   -- 기기가 만든 번호: 같은 기록을 두 번 보내도 한 번만 저장
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  content_id uuid not null,                            -- 미션 세트 id, 또는 '날씨 맞추기' 고정 id
  mode text not null check (mode in ('mission', 'guess')),
  set_name text check (set_name is null or char_length(set_name) <= 30),
  score int not null check (score between 0 and 1000),
  max_score int not null check (max_score between 1 and 1000),
  stages int not null check (stages between 1 and 100),
  duration_sec int check (duration_sec is null or duration_sec between 0 and 86400),
  detail jsonb check (detail is null or pg_column_size(detail) <= 8000),
  created_at timestamptz not null default now(),
  check (score <= max_score),
  unique (student_id, rid)
);
create index weather_records_rank_idx on public.weather_records (teacher_id, content_id, score desc, duration_sec);

alter table public.weather_mission_sets enable row level security;
alter table public.weather_records enable row level security;

grant select on public.weather_mission_sets to authenticated;
grant insert (owner_id, name, missions, is_published) on public.weather_mission_sets to authenticated;
grant update (name, missions, is_published, updated_at) on public.weather_mission_sets to authenticated;
grant delete on public.weather_mission_sets to authenticated;
grant select, delete on public.weather_records to authenticated;

-- 미션 세트: 인증된 교사는 공개된 것만 읽고, 관리자는 전부 읽고 쓴다 (정책은 동작별로 하나씩)
create policy weather_sets_select on public.weather_mission_sets for select to authenticated
  using ((select private.is_admin()) or (is_published and (select private.is_verified_teacher())));
create policy weather_sets_insert on public.weather_mission_sets for insert to authenticated
  with check ((select private.is_admin()) and owner_id = (select auth.uid()));
create policy weather_sets_update on public.weather_mission_sets for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy weather_sets_delete on public.weather_mission_sets for delete to authenticated
  using ((select private.is_admin()));

-- 기록: 쓰기는 서버 함수(service role)뿐. 교사는 자기 학생 기록만 읽고 지운다
create policy weather_records_select on public.weather_records for select to authenticated
  using (teacher_id = (select auth.uid()) and (select private.is_verified_teacher()));
create policy weather_records_delete on public.weather_records for delete to authenticated
  using (teacher_id = (select auth.uid()) and (select private.is_verified_teacher()));

-- 포털 앱 목록에 등록 (파일이 배포된 뒤 켜진 상태로 둔다)
insert into public.apps (slug, name, url, icon, category, sort_order, is_active, color, description)
values ('weather', '기상요소로 날씨 만들기', '/games/weather/', '🌦️', 'game', 10, true, '#3b82f6', '기상 요소를 조절해 날씨를 만들고 미션을 풀어요')
on conflict (slug) do update set name = excluded.name, url = excluded.url, icon = excluded.icon,
  category = excluded.category, is_active = true, description = excluded.description;
