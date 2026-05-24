# `integration_test/`

## 역할

`integration_test/`는 Flutter integration test 형식으로 Supabase Auth, Edge Function, DB 파생 데이터까지 이어지는 E2E 흐름을 검증합니다. 단순 화면 렌더링을 넘어 실제 원격 Supabase API 호출 결과를 확인하는 테스트입니다.

## 주요 파일

| 파일 | 설명 |
|---|---|
| `runner_api_e2e_test.dart` | 테스트 사용자 로그인/생성, `create-run` 호출, `runs`, `run-history`, `point-history`, `user_point_daily`, `profile-leaderboard` 반영 확인 |

## 동작 흐름

```text
flutter test integration_test/runner_api_e2e_test.dart
-> 테스트 사용자 로그인 또는 생성
-> create-run Edge Function 호출
-> DB 저장 결과 확인
-> 기록/포인트/랭킹 API 반영 확인
```

실행 예시:

```bash
flutter test integration_test/runner_api_e2e_test.dart \
  --dart-define=RUNNER_E2E_EMAIL="$RUNNER_E2E_EMAIL" \
  --dart-define=RUNNER_E2E_PASSWORD="$RUNNER_E2E_PASSWORD"
```

## 관련 기능

- Supabase Auth
- 러닝 기록 저장 API
- 러닝 기록 조회 API
- 포인트 이력 조회 API
- 일별 포인트 집계
- 기간별 랭킹 조회

## 참고 사항

- `RUNNER_E2E_EMAIL`과 `RUNNER_E2E_PASSWORD`를 생략하면 테스트가 새 사용자를 생성할 수 있습니다.
- 원격 Supabase 프로젝트에 테스트 데이터가 남을 수 있으므로 운영 데이터와 분리된 테스트 계정 또는 별도 프로젝트 사용을 권장합니다.
- 네트워크 상태와 원격 Supabase 설정에 따라 테스트 결과가 달라질 수 있습니다.
