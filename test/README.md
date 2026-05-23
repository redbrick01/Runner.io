# `test/` 테스트 구조

Flutter 단위 테스트와 widget test가 들어 있다.

## 주요 테스트

| 파일 | 검증 대상 |
|---|---|
| `run_session_engine_test.dart` | 러닝 계산 엔진의 위치 샘플 처리, 거리, 일시정지, 재개, 비정상 샘플 거부 |
| `login_page_test.dart` | 로그인 화면 기본 렌더링/입력 |
| `signup_page_test.dart` | 회원가입 화면 기본 렌더링/입력 |
| `running_map_page_test.dart` | 위치 권한 실패/지도 화면 상태 일부 |
| `run_result_page_test.dart` | 러닝 결과 화면 렌더링 |
| `run_history_page_test.dart` | 러닝 기록 화면 상태 |
| `point_history_page_test.dart` | 포인트 이력 화면 상태 |
| `ranking_page_test.dart` | 랭킹 화면 상태 |
| `profile_edit_page_test.dart` | 프로필 수정 화면 상태 |

## 실행

```bash
flutter test
```

특정 테스트만 실행:

```bash
flutter test test/run_session_engine_test.dart
```

## E2E 테스트

원격 Supabase API/DB까지 확인하는 테스트는 `integration_test/runner_api_e2e_test.dart`에 있다.

```bash
flutter test integration_test/runner_api_e2e_test.dart \
  --dart-define=RUNNER_E2E_EMAIL=your-test-user@example.com \
  --dart-define=RUNNER_E2E_PASSWORD=your-password
```

이 테스트는 실제 Supabase Auth, Edge Function, DB 테이블을 호출한다. 운영 데이터와 섞이지 않도록 전용 테스트 계정 또는 별도 Supabase 프로젝트 사용을 권장한다.

