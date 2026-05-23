# `lib/` Flutter 앱 구조

`lib/`는 Flutter 클라이언트의 핵심 소스이다. 화면, 러닝 계산 엔진, Supabase 호출 계층을 분리한다.

## 진입점

- `main.dart`: Flutter binding 초기화, Supabase 초기화, 세션 기반 첫 화면 분기
- `app_colors.dart`: 앱 전체 색상 토큰

## 폴더별 책임

### `login/`

- `login_page.dart`: 로그인 입력, `AuthService.signIn`, 성공 후 `RunningMapPage` 이동
- `signup_page.dart`: 회원가입 입력, `AuthService.signUp`, 성공 후 로그인 화면 복귀

### `main/`

- `running_map_page.dart`: 앱의 중심 화면. 지도, 위치 권한, 러닝 상태, 영토 overlay, 랭킹, Android/iOS 백그라운드 bridge를 연결한다.
- `run_session_engine.dart`: UI와 독립적인 러닝 계산 로직. 위치 정확도, 비정상 속도, 일시정지, 재개 segment, split 계산을 담당한다.
- `run_result_page.dart`: 러닝 저장 후 결과 리포트 화면.
- `run_history_page.dart`: 기간별 러닝 기록과 요약.
- `point_history_page.dart`: 기간별 포인트 이력과 상세 이동.
- `ranking_page.dart`: 일/주/월/년/전체 랭킹.
- `territory_detail_page.dart`: 영토 상세와 기여자/타임라인.
- `my_page.dart`: 내 정보, 메뉴, 로그아웃, TTS 테스트.
- `profile_edit_page.dart`: 프로필/비밀번호 수정.
- 과거 실험 화면이었던 `mainlist_page.dart`는 현재 앱 흐름에서 사용되지 않아 삭제했다.

### `services/`

화면에서 직접 HTTP/Supabase 세부 구현을 다루지 않도록 만든 서비스 계층이다.

- `supabase_api.dart`를 통해 Edge Function URL, 공통 header, JSON decode, 오류 처리를 통일한다.
- 기능별 서비스는 단일 책임으로 유지한다.
- `user_profile_store.dart`는 프로필 snapshot을 캐시하고 화면 간 로컬 상태를 동기화한다.

## 주요 상태 흐름

```text
LoginPage/SignupPage
-> AuthService
-> Supabase Auth
-> RunningMapPage
-> RunningMapService/ProfileService/TerritoryService/RankingService
-> RunSessionEngine
-> RunService.createRun
-> RunResultPage
```

## 개발 시 주의사항

- 러닝 계산 로직을 바꿀 때는 먼저 `run_session_engine.dart`를 수정하고 `test/run_session_engine_test.dart`를 갱신한다.
- Edge Function 응답 형식을 바꾸면 관련 service와 화면의 null/error 처리를 함께 확인한다.
- 지도와 위치 권한 로직은 widget test에서 완전히 검증하기 어렵기 때문에 실제 기기 테스트가 필요하다.
- Android/iOS MethodChannel 이름은 네이티브 코드와 함께 맞춰야 한다.
