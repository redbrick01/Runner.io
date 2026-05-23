# Runner Flutter 테스트 계획 및 결과 보고서

작성일: 2026-05-24  
대상 프로젝트: `runner_flutter`

## 1. 테스트 개요

본 문서는 현재까지 수행한 테스트 계획, 실제 테스트 결과, 발견된 문제, 수정 사항, 남은 테스트 대상을 정리한다.

테스트는 다음 순서로 진행했다.

1. 프로젝트 구조 및 기능 분석
2. 러닝 동작 로직 단위 테스트
3. Supabase Edge Function 및 DB 통합 테스트
4. Edge Function 배포 후 재검증
5. 테스트 사용자 기반 API/DB E2E 검증
6. Flutter 프론트 widget test 추가 및 실행
7. 남은 프론트 E2E 테스트 대상 정리

## 2. 프로젝트 구조 분석

주요 구조는 다음과 같다.

```text
lib/
  main.dart
  app_colors.dart

  login/
    login_page.dart
    signup_page.dart

  main/
    running_map_page.dart
    run_result_page.dart
    run_history_page.dart
    point_history_page.dart
    ranking_page.dart
    my_page.dart
    profile_edit_page.dart
    territory_detail_page.dart
    run_session_engine.dart

  services/
    auth_service.dart
    run_service.dart
    run_history_service.dart
    point_history_service.dart
    ranking_service.dart
    profile_service.dart
    territory_service.dart
    running_map_service.dart
    supabase_api.dart
    user_profile_store.dart

supabase/
  functions/
  migrations/

test/
integration_test/
```

전체 동작 흐름은 다음과 같다.

```text
앱 실행
→ Supabase 초기화
→ 세션 확인
→ 세션 없음: LoginPage
→ 세션 있음: RunningMapPage
→ 위치 권한/지도/영토/랭킹 로드
→ 러닝 시작
→ 위치 샘플 수집
→ 러닝 종료
→ create-run Edge Function 호출
→ runs / splits / point_history / user_point_daily / ranking 반영
→ RunResultPage 표시
```

## 3. 기능별 테스트 계획

| 기능 | 테스트 목적 | 테스트 방식 | 우선순위 |
|---|---|---|---|
| 앱 부팅 | Supabase 초기화와 세션 분기 검증 | widget/integration | 높음 |
| 로그인 | 입력 검증, 실패 표시, 성공 이동 검증 | widget/integration | 매우 높음 |
| 회원가입 | 입력 검증, 비밀번호 확인, 성공/실패 처리 검증 | widget | 중간 |
| 러닝 엔진 | 위치 샘플 처리, 거리/속도/고도/일시정지 검증 | unit | 매우 높음 |
| 러닝 지도 | 위치 권한, 지도 UI, 러닝 상태 UI 검증 | widget/integration | 매우 높음 |
| 러닝 저장 | create-run 호출과 저장 실패/성공 처리 검증 | integration/E2E | 매우 높음 |
| DB 파생 데이터 | point_history, user_point_daily, ranking 반영 검증 | API/DB integration | 매우 높음 |
| 러닝 결과 | 기록 수치, split, 경로 없음 상태 검증 | widget | 높음 |
| 기록/포인트/랭킹 | 로딩, 빈 상태, API 실패 복구 검증 | widget/integration | 중간 |
| 프로필 | 입력 검증, 수정, 로그아웃 검증 | widget/integration | 높음 |

## 4. 백엔드/DB 테스트 진행 결과

### 4.1 러닝 엔진 단위 테스트

대상 파일:

- `test/run_session_engine_test.dart`
- `lib/main/run_session_engine.dart`

검증 내용:

- 유효한 위치 샘플 수락
- 부정확한 샘플 거부
- 일시정지 중 샘플 무시
- 재개 후 먼 위치에서 새 segment 시작
- warmup sample 처리
- 비정상 고속 이동 거부
- active run이 아닐 때 snapshot 제한

실행 결과:

```text
flutter test test/run_session_engine_test.dart
All tests passed! 7 tests
```

상태: 성공

### 4.2 Edge Function 정적 검증

대상:

- `supabase/functions/create-run/index.ts`
- `supabase/functions/update-profile/index.ts`
- `supabase/functions/territory-geojson/index.ts`

검증 내용:

- Deno 타입/문법 확인
- env 누락 시 top-level crash 방지
- JSON 에러 응답 형식 확인
- territory bbox 필터링 로직 확인

결과:

```text
deno check
통과
```

상태: 성공

### 4.3 Edge Function 배포

배포 대상 Supabase project:

```text
ifqrceunenzqusppfxgi
```

배포 함수:

```text
create-run
update-profile
territory-geojson
```

상태: 배포 완료

### 4.4 배포 함수 재검증

검증 내용:

- `create-run`
  - GET 요청: 405 확인
  - 빈 POST + anon bearer: 401 Invalid token 확인
- `update-profile`
  - GET 요청: 405 확인
  - content-type 누락 POST: 400 확인
- `territory-geojson`
  - 잘못된 bbox: 400 확인
  - 정상 bbox: bbox 밖 geometry 제거 확인

상태: 성공

### 4.5 테스트 사용자 기반 API/DB 통합 테스트

테스트 사용자:

```text
codex_test_20260524000103@example.com
```

검증 흐름:

```text
테스트 사용자 access token 확보
→ create-run 호출
→ runs 저장 확인
→ run-history 확인
→ point-history 확인
→ user_point_daily 확인
→ ranking/profile-leaderboard 확인
```

결과:

- `create-run` 정상 저장 확인
- `run-history` 반영 확인
- `point-history` 반영 확인
- `profile-leaderboard` 반영 확인
- `user_point_daily.total_points` 반영 확인
- 최초 검증에서 `user_point_daily.run_points`가 증가하지 않는 문제 발견

상태: 부분 실패 후 수정 완료

## 5. 발견된 문제 및 수정 결과

### 5.1 Supabase API Authorization fallback 문제

문제:

- 세션이 없을 때 Authorization header가 빈 bearer로 들어갈 수 있었다.

수정:

- `lib/services/supabase_api.dart`
- access token이 없으면 anon key를 bearer로 사용하도록 변경

검증:

- `flutter analyze` 통과
- API 호출 재검증 완료

상태: 해결

### 5.2 Edge Function env 초기화 문제

문제:

- env 누락 시 함수 top-level에서 crash 가능성이 있었다.

수정:

- `create-run`, `update-profile`에서 Supabase client lazy init 적용
- env 누락 시 JSON 500 응답 반환

검증:

- Deno check 통과
- 배포 후 HTTP 응답 재검증 완료

상태: 해결

### 5.3 territory-geojson bbox 필터링 문제

문제:

- bbox 요청에서 bbox 밖 polygon/multipolygon 일부가 포함될 수 있었다.

수정:

- bbox parsing/filtering 추가
- MultiPolygon 내부 ring 단위 필터링 적용

검증:

- 잘못된 bbox 400 확인
- 정상 bbox에서 외부 geometry 제거 확인

상태: 해결

### 5.4 user_point_daily.run_points 미반영 문제

문제:

- 러닝 저장 후 `total_points`는 증가했지만 `run_points`가 증가하지 않았다.

원인:

- DB trigger/function `handle_run_points()`가 `total_points`만 갱신하고 `run_points`를 갱신하지 않았다.

수정:

- migration 추가:

```text
supabase/migrations/20260524000500_track_run_points_in_user_point_daily.sql
```

수정 내용:

- future run insert/upsert 시 `run_points`, `total_points` 모두 증가
- 기존 `point_history.event_type = run_created` 데이터 기준으로 `run_points` backfill
- 기존 `total_points`는 임의로 재계산하지 않음

검증:

- 기존 row backfill 확인
- 두 번째 테스트 run 생성 후 `total_points=10`, `run_points=10` 확인
- day ranking 반영 확인

상태: 해결

## 6. 자동화 E2E 테스트 결과

실제 기기에서 수동 러닝 테스트가 어려운 상황을 보완하기 위해 API/DB E2E 테스트를 추가했다.

대상 파일:

```text
integration_test/runner_api_e2e_test.dart
```

검증 흐름:

```text
테스트 사용자 로그인
→ create-run Edge Function 호출
→ 저장된 run 응답 확인
→ run-history 확인
→ point-history 확인
→ user_point_daily total_points/run_points 증가 확인
→ profile-leaderboard 반영 확인
```

실행 명령:

```bash
flutter test integration_test/runner_api_e2e_test.dart \
  --dart-define=RUNNER_E2E_EMAIL=codex_test_20260524000103@example.com \
  --dart-define=RUNNER_E2E_PASSWORD=CodexTest!20260524000103
```

결과:

```text
All tests passed! 1 test
```

상태: 성공

주의:

- 이 테스트는 원격 Supabase DB에 실제 테스트 run 데이터를 추가한다.
- 운영 환경과 분리된 테스트 계정/테스트 데이터 정책이 필요하다.

## 7. Flutter 프론트 테스트 계획

프론트 테스트는 다음 순서로 계획했다.

1. `LoginPage` widget test
2. `SignupPage` widget test
3. `ProfileEditPage` validation test
4. `RunResultPage` rendering test
5. 목록형 화면 empty/loading/failure state test
6. `RunningMapPage` smoke test
7. `RunningMapPage` 러닝 상태 버튼 흐름 test
8. 로그인 후 주요 화면 이동 integration test
9. 러닝 저장 이후 기록 화면 반영 integration test

## 8. Flutter 프론트 테스트 진행 결과

### 8.1 LoginPage

대상 파일:

```text
test/login_page_test.dart
```

검증 내용:

- 로그인 화면 렌더링
- 이메일/비밀번호 입력 필드 표시
- 비밀번호 필드 obscure 처리
- 빈 입력 시 SnackBar 표시
- Sign Up 버튼으로 회원가입 화면 이동

결과:

```text
All tests passed! 4 tests
```

상태: 성공

### 8.2 SignupPage

대상 파일:

```text
test/signup_page_test.dart
```

검증 내용:

- 회원가입 화면 렌더링
- password / confirm password obscure 처리
- 빈 입력 validation
- 비밀번호 불일치 validation
- app bar back action으로 pop 확인

결과:

```text
All tests passed! 5 tests
```

상태: 성공

### 8.3 ProfileEditPage

대상 파일:

```text
test/profile_edit_page_test.dart
```

검증 내용:

- 초기 loading 표시
- 프로필 form 렌더링
- 새 비밀번호 필드 obscure 처리
- 잘못된 키 입력 validation
- 잘못된 몸무게 입력 validation
- 로그아웃 dialog 표시 및 취소

결과:

```text
All tests passed! 5 tests
```

상태: 성공

비고:

- Supabase가 초기화되지 않은 테스트 환경에서 profile fetch 실패 로그가 출력된다.
- 화면은 실패를 흡수하고 정상 렌더링되므로 테스트는 통과한다.

### 8.4 RunResultPage

대상 파일:

```text
test/run_result_page_test.dart
```

검증 내용:

- 경로 데이터 없음 상태 표시
- 주요 기록 수치 렌더링
- 거리/시간/페이스/칼로리/상승/점령 면적 표시
- split row 정렬 및 표시
- 확인 버튼으로 page pop

결과:

```text
All tests passed! 3 tests
```

상태: 성공

### 8.5 RankingPage

대상 파일:

```text
test/ranking_page_test.dart
```

검증 내용:

- loading 표시
- API 실패 후 빈 상태 표시
- 일/주/월/년/전체 range tab 표시
- 실패 상태에서 range 변경 시 화면 안정성 확인

결과:

```text
All tests passed! 2 tests
```

상태: 성공

### 8.6 RunHistoryPage

대상 파일:

```text
test/run_history_page_test.dart
```

검증 내용:

- loading 표시
- API 실패 후 빈 상태 표시
- `러닝 기록이 없습니다.` 표시

결과:

```text
All tests passed! 1 test
```

상태: 성공

### 8.7 PointHistoryPage

대상 파일:

```text
test/point_history_page_test.dart
```

검증 내용:

- loading 표시
- API 실패 후 빈 상태 표시
- `내역이 없습니다.` 표시

결과:

```text
All tests passed! 1 test
```

상태: 성공

### 8.8 RunningMapPage

대상 파일:

```text
test/running_map_page_test.dart
```

검증 내용:

- 위치 서비스 unavailable fake 적용
- native 위치 서비스가 없어도 crash 없이 렌더링되는지 확인
- 기본 top banner 표시 확인
- bottom navigation label 표시 확인

결과:

```text
All tests passed! 1 test
```

상태: 성공

## 9. 전체 테스트 실행 결과

실행 명령:

```bash
flutter test
```

결과:

```text
All tests passed! 29 tests
```

실행 명령:

```bash
flutter analyze
```

결과:

```text
No issues found!
```

현재 상태:

```text
Unit / Widget / API E2E 주요 테스트 통과
```

## 10. 현재까지 테스트 완료 범위

완료:

- 러닝 엔진 단위 테스트
- Edge Function 타입/응답 검증
- Edge Function 배포
- 배포 함수 HTTP 재검증
- 테스트 사용자 access token 기반 create-run 통합 검증
- DB 파생 테이블 검증
- user_point_daily run_points 문제 수정 및 검증
- API/DB 자동화 E2E 테스트
- Flutter 로그인/회원가입 프론트 widget test
- Flutter 프로필 validation widget test
- Flutter 러닝 결과 화면 widget test
- Flutter 목록형 화면 failure/empty state widget test
- Flutter RunningMapPage smoke test
- `flutter test` 전체 통과
- `flutter analyze` 통과

## 11. 남은 테스트 대상

아직 남은 주요 테스트는 다음과 같다.

### 11.1 RunningMapPage 러닝 상태 UI

검증 필요:

- 시작 버튼 tap
- 카운트다운 표시
- 러닝 시작 상태 전환
- 일시정지
- 재개
- 취소 dialog
- 종료 버튼
- 저장 중 상태
- 저장 실패 SnackBar
- 중복 tap 방지

현재 제약:

- `RunningMapPage`가 GoogleMap, Geolocator, MethodChannel, TTS, Supabase service에 강하게 결합되어 있다.
- 안정적인 테스트를 위해 fake 위치 스트림과 native channel mock이 더 필요하다.

### 11.2 실제 앱 화면 간 integration test

검증 필요:

- 로그인 → 지도 화면 진입
- 지도 → 통계 화면 이동
- 지도 → 마이 화면 이동
- 지도 → 랭킹/포인트 화면 이동
- 프로필 수정 후 화면 반영
- 러닝 저장 후 기록 화면 반영

### 11.3 성공 API 응답 기반 목록 화면 테스트

현재는 API 실패/빈 상태 중심으로 검증했다.

추가 검증 필요:

- 랭킹 목록 정상 표시
- 포인트 내역 정상 표시
- 러닝 기록 정상 표시
- 기록 item tap 후 RunResultPage 이동
- point-history run item tap 후 연결된 run 열기

이를 위해 service dependency injection 또는 mock 가능한 service layer가 필요하다.

### 11.4 레이아웃/반응형 테스트

검증 필요:

- iPhone SE 크기
- 일반 iPhone 크기
- 큰 화면
- 긴 닉네임
- 긴 에러 메시지
- 키보드 표시 상태
- 텍스트 overflow 여부

## 12. 향후 테스트 실행 계획

권장 다음 순서:

1. `RunningMapPage` 테스트 가능성을 높이기 위한 fake service/channel 구조 추가
2. 러닝 시작/일시정지/재개/취소 UI widget test 작성
3. 저장 실패 UI 테스트 작성
4. 목록 화면에 mock service 주입 구조 추가
5. 정상 데이터 기반 ranking/history/point 화면 테스트 작성
6. 로그인 후 주요 화면 이동 integration test 작성
7. 실제 디바이스 가능 시 GPS 기반 수동 E2E 또는 field test 수행

## 13. 테스트 실행 명령 모음

전체 테스트:

```bash
flutter test
```

정적 분석:

```bash
flutter analyze
```

러닝 엔진 단위 테스트:

```bash
flutter test test/run_session_engine_test.dart
```

프론트 widget test:

```bash
flutter test test/login_page_test.dart
flutter test test/signup_page_test.dart
flutter test test/profile_edit_page_test.dart
flutter test test/run_result_page_test.dart
flutter test test/ranking_page_test.dart
flutter test test/run_history_page_test.dart
flutter test test/point_history_page_test.dart
flutter test test/running_map_page_test.dart
```

API/DB E2E 테스트:

```bash
flutter test integration_test/runner_api_e2e_test.dart \
  --dart-define=RUNNER_E2E_EMAIL=codex_test_20260524000103@example.com \
  --dart-define=RUNNER_E2E_PASSWORD=CodexTest!20260524000103
```

## 14. 최신 지도/기기 검증 반영

### 14.1 지도 overlay 정리

변경 내용:

- 현재 위치 마커를 작은 dot 형태로 축소해 지도와 영토를 가리지 않도록 조정
- 영토 닉네임 라벨은 현재 사용자 영토 대표 1개에만 표시
- 상대 영토는 색상 polygon만 표시하고 닉네임 marker는 생성하지 않음
- 영토/프로필 `color_hex` 값이 잘못되어도 기본 색상으로 대체
- 로그인 직후 프로필 조회, 위치 초기화, 위치 stream 오류가 앱 종료로 번지지 않도록 방어 처리

검증:

```bash
flutter analyze lib/main/running_map_page.dart
flutter test test/running_map_page_test.dart
flutter test
```

결과:

```text
No issues found
All tests passed! 29 tests
```

### 14.2 iOS 실제 기기 실행

변경 내용:

- `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig`에서 `Local.xcconfig`를 선택적으로 include
- `ios/Flutter/Local.xcconfig`를 Git 제외 대상으로 추가
- iOS Google Maps key는 `GOOGLE_MAPS_API_KEY` build setting으로 주입

검증 내용:

- iPhone 실제 기기에서 `flutter run -d 00008150-001225DC1186401C` 실행
- Supabase 초기화 성공 확인
- 지도 화면 진입 후 `user-ranking`, `territory-geojson`, `profile-leaderboard` API 응답 확인
- Google Maps API key 미설정으로 인한 `GMSServicesException` 재발 없음

## 15. 결론

현재 프로젝트는 핵심 러닝 로직, 서버 저장 흐름, DB 파생 데이터, 주요 Flutter 프론트 화면의 기본 안정성 테스트까지 통과했다.

현재 가장 큰 남은 리스크는 `RunningMapPage`의 실제 러닝 UI 상태 전환과 native 의존 기능이다. 이 영역은 실제 앱 핵심 경험에 해당하므로 다음 테스트 단계에서 가장 높은 우선순위로 다뤄야 한다.
