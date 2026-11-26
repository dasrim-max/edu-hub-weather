# 기상요소로 날씨 만들기 (쌤허브 앱)

쌤허브(ssamhub.com) 안에서 `/games/weather/` 로 열리는 앱입니다. 이 저장소는 **이 앱만** 다룹니다.

- **앱 버전**: v1.1 (`site/index.html` 의 `APP_VERSION`, 앱 이름표에 보임)
- **쌤허브 공통 규칙 기준 날짜**: 2026-11-26 (쌤허브 v2.1 · 포털 `docs/변경-기록.md` 이 날짜까지 반영)

## 버전 기록
- **v1.1** (2026-11-26): 쌤허브 v2.1 공통 모듈로 옮김
  - 수업 흐름으로 들어온 학생도 점수 저장·순위·미션 세트 목록이 되게: 서버 함수 `weather-record` 가 공통 입구 `studentRequest(req, "weather", { entry: true })` 사용(자체 `usableLink` 삭제, 공통 `APP_ENTRY_ID`). 세트는 "공개된 것 또는 이 교사가 만든 것"만
  - 화면: 앱 입구 `initApp`, 학생 서버 호출 `me.call`(입장 시간이 끝나면 공통 모듈이 입장 화면으로), 확인 창·사전 문제·순위표는 `/shared/dialog.js`, 미션 세트 고르기는 `pickContent`, 이 기기 저장은 `local("weather")`(예전 저장 값은 처음 열 때 옮김)
  - 학생 이름은 `textContent` 로만 그림. 교사 화면 "학생 명단"은 읽기만(추가·이름 고치기·지우기는 쌤허브 학생 명단으로 연결)
  - 순위표에서 쓰이지 않던 기능(오늘 전체 기록·학교 검색·기록 수정) 정리, 기록 번호가 없는 줄이 모두 '내 기록'으로 칠해지던 것 고침
- v1.0: 쌤허브 연결(앱 이름표·애플 기본 스타일·메뉴 글자 20px·앱 제목 없음)

| 폴더 | 내용 |
|---|---|
| `site/` | 화면 파일. 포털이 빌드할 때 이 폴더를 가져가 `/games/weather/` 에 둡니다 |
| `supabase/functions/` | 이 앱 전용 서버 함수 (`weather-record`) |
| `supabase/migrations/` | 이 앱 전용 DB 변경 (표·RLS·포털 앱 등록) |
| `supabase/tests/` | RLS 시험 (한 트랜잭션에서 실행 후 롤백) |

## 작업 규칙
- 공통 모듈(`/shared/`: 로그인·학생 입장·초대)과 공통 표(학생 명단·링크 등)는 **포털 저장소(edu-hub)** 소관입니다. 여기서 고치지 않습니다.
- 이 앱의 표 이름은 `weather_` 로 시작합니다. 공통 표를 바꾸는 변경은 포털 저장소에서 합니다.
- 화면 파일은 `/shared/index.js` 를 절대 경로로 불러옵니다. 따로 열어 보려면 포털 사이트(또는 로컬에서 포털을 빌드한 `dist`) 안에서 확인하세요.
- `site/` 를 고쳐 main에 올리면 Actions가 포털을 다시 빌드해 반영합니다.
- 서버 함수를 고쳐 main에 올리면 Actions가 Supabase에 배포합니다.

## GitHub 비밀 값(Settings → Secrets → Actions)
- `CF_PAGES_DEPLOY_HOOK`: Cloudflare Pages(edu-hub 프로젝트) 배포 후크 주소
- `SUPABASE_ACCESS_TOKEN`: Supabase 개인 접근 토큰
- `PORTAL_READ_TOKEN`: edu-hub 저장소 읽기 전용 토큰

## 미션 세트
미션 세트는 관리자가 `교사 모드 → 미션 출제`에서 만들어 서버(`weather_mission_sets`)에 저장·공개합니다.
