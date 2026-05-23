# 대시보드 데이터 미표시 에러 리포트

작성일: 2026-05-24  
대상 프로젝트: `runner_flutter`  
관련 화면: `RunningMapPage` 메인 지도/대시보드

## 1. 에러 요약

앱 최초 실행 시 메인 대시보드의 점령 면적, 랭킹, 포인트는 정상 표시되지만, 앱을 백그라운드로 보낸 뒤 다시 복귀하면 해당 값이 표시되지 않거나 0 값처럼 보이는 문제가 보고되었다.

앱을 완전히 종료한 뒤 재실행하면 다시 정상 표시되는 것으로 보아, 최초 부팅 데이터 로드보다 앱 복귀 시점의 재조회/상태 갱신 흐름이 핵심 원인으로 판단했다.

## 2. 재현 절차

1. 앱 실행
2. 로그인 세션이 있는 상태로 메인 화면 진입
3. 상단 대시보드의 점령 면적, 랭킹, 포인트 정상 표시 확인
4. 홈 버튼 또는 앱 전환으로 앱을 백그라운드로 이동
5. 다른 앱 사용 후 Runner 앱으로 복귀
6. 상단 대시보드 값이 유지되는지 확인

## 3. 기대 동작

앱 복귀 시 대시보드 데이터는 기존 정상 값을 유지하거나, 최신 데이터로 재조회되어 다시 표시되어야 한다.

## 4. 실제 동작

복귀 시점에 대시보드 값이 비어 보이거나 0 값으로 갱신될 수 있다. 완전 종료 후 재실행하면 정상 표시된다.

## 5. 데이터 흐름

대시보드 값은 `lib/main/running_map_page.dart`의 로컬 상태에 저장된다.

```text
RunningMapPage
-> _fetchUserRanking()
-> RunningMapService.fetchUserProfile(force: true)
-> UserProfileStore.fetch(force: true)
-> ProfileService.fetchCurrentProfile()
-> Supabase Edge Function user-ranking
```

표시 위치:

- `lib/main/running_map_page.dart`의 `_buildTopBanner()`
- 점령 면적: `_occupiedArea`
- 랭킹: `_ranking`
- 포인트: `_points`

초기 로드:

- `RunningMapPage.initState()`
- `_fetchUserRanking()` 호출

앱 복귀 로드:

- `RunningMapPage.didChangeAppLifecycleState()`
- `AppLifecycleState.resumed` 처리

## 6. 확인한 코드 위치

| 파일 | 위치 | 내용 |
|---|---:|---|
| `lib/main/running_map_page.dart` | `initState()` | 최초 진입 시 `_fetchUserRanking()` 호출 |
| `lib/main/running_map_page.dart` | `didChangeAppLifecycleState()` | 앱 복귀 시 대시보드/위치/러닝 상태 갱신 |
| `lib/main/running_map_page.dart` | `_fetchUserRanking()` | 프로필 스냅샷을 받아 `_points`, `_occupiedArea`, `_ranking` 반영 |
| `lib/services/running_map_service.dart` | `fetchUserProfile()` | `UserProfileStore`로 프로필 조회 위임 |
| `lib/services/user_profile_store.dart` | `fetch()` | 프로필 캐시 및 API 재조회 관리 |
| `lib/services/profile_service.dart` | `fetchCurrentProfile()` | `user-ranking` Edge Function 호출 |
| `supabase/functions/user-ranking/index.ts` | handler | 로그인 사용자 기준 rank/area/profile 응답 생성 |

## 7. 원인 분석

### 7.1 앱 생명주기 처리

`RunningMapPage`는 `WidgetsBindingObserver`를 사용하고 있으며 `AppLifecycleState.resumed` 콜백도 존재한다. 따라서 생명주기 처리가 완전히 누락된 상태는 아니었다.

기존 코드는 복귀 시 `_fetchUserRanking()`을 호출했지만, 이 함수 내부에는 최근 5초 이내 호출을 무시하는 throttle 로직이 있었다. 복귀 직전 또는 초기화 직후 호출 이력이 남아 있으면 복귀 시점의 재조회가 생략될 수 있었다.

### 7.2 상태 관리 및 캐시 문제

`UserProfileStore`는 싱글턴 캐시 `_current`를 유지한다. API 실패가 throw 되는 경우에는 기존 캐시를 유지하지만, `user-ranking` 응답이 `{"data": null}`처럼 200 응답이면서 프로필이 비어 있는 경우에는 기존 코드가 이를 rank/area/points가 모두 0인 정상 스냅샷처럼 파싱할 수 있었다.

이 경우 `_fetchUserRanking()`이 다음 상태를 대시보드에 반영한다.

```text
_points = 0
_occupiedArea = 0
_ranking = 0
```

사용자 입장에서는 데이터가 표시되지 않는 것처럼 보인다.

### 7.3 앱 재시작 시 정상인 이유

완전 종료 후 재실행하면 Supabase 초기화와 세션 확인이 처음부터 다시 진행된다. 이후 `RunningMapPage.initState()`에서 프로필 조회가 실행되므로 정상 응답을 받아 대시보드가 표시된다.

반면 백그라운드 복귀는 이미 살아 있는 화면과 캐시를 재사용한다. 이 시점에 세션 갱신, 위치 재시작, 지도/영토 갱신, 프로필 재조회가 동시에 발생할 수 있어 일시적인 빈 응답이나 갱신 스킵이 화면 상태에 영향을 줄 수 있다.

## 8. 수정 내용

### 8.1 앱 복귀 시 강제 재조회

수정 파일:

- `lib/main/running_map_page.dart`

변경 내용:

```dart
unawaited(_fetchUserRanking(force: true));
```

`AppLifecycleState.resumed`에서 5초 throttle에 걸리지 않도록 `force: true`로 대시보드 데이터를 강제 갱신한다.

### 8.2 빈 프로필 응답 방어

수정 파일:

- `lib/services/user_profile_store.dart`

변경 내용:

- `UserProfileSnapshot.hasIdentityData` 추가
- `id`, `userId`, `nickName`이 모두 없는 응답은 빈 프로필로 간주
- 빈 프로필은 정상 스냅샷으로 캐시에 저장하지 않음
- 기존 정상 캐시가 0 값으로 덮이는 것을 방지

### 8.3 회귀 테스트 추가

수정 파일:

- `test/user_profile_store_test.dart`

추가 테스트:

- `{"data": null}` 응답이 identity 없는 스냅샷으로 판정되는지 확인
- 정상 `user-ranking` 응답에서 rank/area/points/userId가 파싱되는지 확인

## 9. 검증 결과

### 9.1 정적 분석

```text
flutter analyze lib/main/running_map_page.dart lib/services/user_profile_store.dart
```

결과:

```text
No issues found!
```

### 9.2 Widget/Unit 테스트

```text
flutter test test/user_profile_store_test.dart test/running_map_page_test.dart
```

결과:

```text
All tests passed!
```

### 9.3 iPhone 실기기 실행

대상 기기:

```text
iPhone (iOS 26.3.1) - 00008150-001225DC1186401C
```

실행 명령:

```text
flutter run -d 00008150-001225DC1186401C --debug --no-resident
```

결과:

- Xcode build 성공
- iPhone 설치 및 실행 성공
- Supabase 초기화 로그 확인
- 명령 종료 코드 0
- Flutter 디버그 연결은 실행 직후 `Lost connection to device`로 종료됨

### 9.4 iPhone 통합 테스트

실행 명령:

```text
flutter test integration_test/runner_api_e2e_test.dart -d 00008150-001225DC1186401C
```

결과:

```text
All tests passed!
```

검증 범위:

- 테스트 사용자 인증 또는 생성
- `create-run` 호출
- `run-history` 반영
- `point-history` 반영
- `user_point_daily` 반영
- `profile-leaderboard` 랭킹 상태 반영

## 10. 남은 확인 사항

백그라운드 복귀 UI 시나리오는 물리 기기 조작이 필요하다. 자동 테스트로 API/DB 흐름과 기기 실행은 확인했지만, 다음 수동 확인은 별도로 수행해야 한다.

1. 앱 실행 후 메인 대시보드 값 확인
2. 홈 버튼 또는 앱 전환으로 백그라운드 이동
3. 다른 앱 사용 후 복귀
4. 점령 면적, 랭킹, 포인트가 유지되거나 재조회되는지 확인
5. 장시간 백그라운드 후 복귀 시 동일 동작 확인
6. 네트워크 불안정 상태에서 복귀 시 기존 정상 값이 0으로 덮이지 않는지 확인

## 11. 결론

이번 수정은 기존 구조를 유지하면서 앱 복귀 시 대시보드 재조회 신뢰성을 높이고, 빈 프로필 응답으로 정상 캐시가 0 값에 의해 덮이는 문제를 방어한다.

현재 자동 검증과 iPhone 실기기 통합 테스트는 통과했으며, 최종적으로는 실기기에서 백그라운드 복귀 수동 시나리오를 확인하면 된다.
