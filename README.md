# 기상요소로 날씨 만들기 (쌤허브 앱)

쌤허브(ssamhub.com) 안에서 `/games/weather/` 로 열리는 앱입니다. 이 저장소는 **이 앱만** 다룹니다.

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
