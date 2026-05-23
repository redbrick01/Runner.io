# `integration_test/` E2E 테스트

이 폴더는 Flutter integration test 형식으로 원격 Supabase API와 DB 파생 데이터까지 확인한다.

## 현재 테스트

- `runner_api_e2e_test.dart`
  - Auth 로그인 또는 고유 테스트 사용자 생성
  - `create-run` Edge Function 호출
  - `runs` 저장 결과 확인
  - `run-history` 반영 확인
  - `point-history` 반영 확인
  - `user_point_daily.run_points`, `user_point_daily.total_points` 누적 확인
  - `profile-leaderboard`의 현재 사용자 점수 확인

## 실행

```bash
flutter test integration_test/runner_api_e2e_test.dart \
  --dart-define=RUNNER_E2E_EMAIL=your-test-user@example.com \
  --dart-define=RUNNER_E2E_PASSWORD=your-password
```

`RUNNER_E2E_EMAIL`과 `RUNNER_E2E_PASSWORD`를 생략하면 테스트가 매번 새 사용자를 만든다. 원격 프로젝트에 데이터가 남으므로 장기적으로는 테스트 전용 Supabase 프로젝트를 두는 것이 좋다.

