# `test/`

## 역할

`test/`는 Flutter 단위 테스트와 widget test를 보관합니다. 러닝 계산 엔진처럼 UI와 분리된 핵심 로직과 주요 화면의 기본 렌더링/상태를 검증합니다.

## 주요 파일

| 파일 | 검증 대상 |
|---|---|
| `run_session_engine_test.dart` | 위치 샘플 처리, 거리 계산, 일시정지/재개, 비정상 샘플 거부 등 러닝 계산 엔진 |
| `login_page_test.dart` | 로그인 화면 기본 렌더링과 입력 |
| `signup_page_test.dart` | 회원가입 화면 기본 렌더링과 입력 |
| `running_map_page_test.dart` | 지도 화면의 일부 상태와 위치 권한 실패 흐름 |
| `run_result_page_test.dart` | 러닝 결과 화면 렌더링 |
| `run_history_page_test.dart` | 러닝 기록 화면 상태 |
| `statistics_service_test.dart` | 기간별 통계 집계, 최근 7일 거리, 개인 최고 기록 계산 |
| `statistics_page_test.dart` | 분석 화면의 빈 상태, 요약 카드, 기간 전환 |
| `point_history_page_test.dart` | 포인트 이력 화면 상태 |
| `ranking_page_test.dart` | 랭킹 화면 상태 |
| `profile_edit_page_test.dart` | 프로필 수정 화면 상태 |

## 동작 흐름

```text
flutter test
-> Dart/Flutter test runner 실행
-> run_session_engine 단위 테스트
-> 주요 화면 widget test
-> 결과 출력
```

특정 테스트만 실행:

```bash
flutter test test/run_session_engine_test.dart
```

## 관련 기능

- 러닝 세션 계산 검증
- 인증 화면 렌더링 검증
- 러닝 결과/기록/분석/포인트/랭킹/프로필 화면 기본 상태 검증

## 참고 사항

- 지도, 위치 권한, Android/iOS 백그라운드 기능은 widget test만으로 충분히 검증하기 어렵기 때문에 실제 기기 수동 테스트가 필요합니다.
- Supabase API와 DB 파생 데이터까지 확인하는 테스트는 `integration_test/`에 있습니다.
- 보고서에서 서비스 계층 테스트 확대가 향후 개선 과제로 언급되어 있습니다.
