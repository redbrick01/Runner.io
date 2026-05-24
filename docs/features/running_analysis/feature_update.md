# 러닝 분석 화면 및 iOS release 실행 변경 기록

작성일: 2026-05-24

## 개요

러닝 기록을 단순 목록으로만 확인하던 흐름에 개인 분석 화면을 추가했다. 새 화면은 저장된 러닝 기록을 기반으로 주간/월간/전체 요약, 최근 7일 거리 그래프, 이전 기간 대비 거리 변화, 개인 최고 기록을 보여준다.

또한 iOS 실제 기기에서 `flutter run --release` 실행 시 `objective_c.framework` 코드 서명 검증 실패로 앱 설치가 중단되는 문제를 수정했다.

## 사용자 화면 변경

### 하단 바

| 항목 | 변경 전 | 변경 후 |
|---|---|---|
| 첫 번째 탭 | `홈`, 동작 없음 | `분석`, `StatisticsPage`로 이동 |
| 두 번째 탭 | `통계`, 새 분석 화면 이동 | `통계`, 기존 `RunHistoryPage` 유지 |

`통계` 탭은 기존 러닝 기록/리포트 화면 역할을 유지한다. 새로 추가한 `분석` 탭은 개인 성장 요약과 그래프를 보여주는 별도 화면이다.

### 마이페이지

마이페이지에서는 두 기능을 분리했다.

- `러닝 통계`: 새 분석 화면으로 이동
- `러닝 리포트`: 기존 러닝 기록과 상세 결과 화면으로 이동

## 추가된 Dart 파일

| 파일 | 역할 |
|---|---|
| `lib/main/statistics_page.dart` | 분석 화면 UI, 기간 선택, 요약 카드, 최근 7일 막대그래프, 개인 최고 기록 표시 |
| `lib/services/statistics_service.dart` | `RunHistoryEntry` 목록 기반 통계 집계 |
| `test/statistics_page_test.dart` | 분석 화면 빈 상태, 요약 카드, 기간 전환 widget test |
| `test/statistics_service_test.dart` | 통계 집계 로직 단위 테스트 |

## 통계 계산 기준

| 항목 | 계산 방식 |
|---|---|
| 총 거리 | 선택 기간 내 `distanceMetres` 합계 |
| 총 시간 | 선택 기간 내 `durationSeconds` 합계 |
| 러닝 횟수 | 선택 기간 내 러닝 기록 수 |
| 평균 페이스 | 총 시간 / 총 거리 기준 |
| 획득 포인트 | 선택 기간 내 `point` 합계 |
| 최근 7일 거리 | 오늘 포함 최근 7일의 날짜별 거리 합계 |
| 최장 거리 | 전체 기록 중 `distanceMetres` 최대값 |
| 최고 페이스 | 100m 이상 기록 중 페이스가 가장 빠른 기록 |
| 최대 점령 면적 | 전체 기록 중 `area` 또는 `area_m2` 최대값 |

## iOS release 설치 문제 수정

### 증상

```text
Failed to verify code signature of ... Runner.app/Frameworks/objective_c.framework
0xe8008014 (The executable contains an invalid signature.)
```

`flutter run --release`에서 Xcode build는 성공했지만, 실제 iPhone 설치 단계에서 앱 무결성 검증에 실패했다.

### 원인

`supabase_flutter`의 의존성 경로에서 `path_provider_foundation`이 포함되고, 이 과정에서 `objective_c` native asset framework가 앱 번들에 포함된다. 해당 framework가 ad-hoc 서명 상태로 남고 `x86_64` slice까지 포함되어 iPhone의 코드 서명 검증을 통과하지 못했다.

### 수정

`ios/Runner.xcodeproj/project.pbxproj`에 `Sign Flutter Native Assets` build phase를 추가했다.

수행 내용:

- `Runner.app/Frameworks/objective_c.framework/objective_c` 존재 여부 확인
- `x86_64` slice가 있으면 제거
- Xcode가 제공하는 `EXPANDED_CODE_SIGN_IDENTITY`로 framework 재서명

## 검증 결과

자동 테스트:

```text
flutter analyze
flutter test test/statistics_page_test.dart test/running_map_page_test.dart
flutter test test/statistics_page_test.dart test/run_history_page_test.dart test/running_map_page_test.dart
flutter test
```

iOS release 실행:

```text
flutter build ios --release
xcrun devicectl device install app --device 9C5F1A9F-C922-54FB-9190-CAE01A916CA5 build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device 9C5F1A9F-C922-54FB-9190-CAE01A916CA5 com.example.runnerFlutter
flutter run --release -d 00008150-001225DC1186401C
```

상태: 성공

## 남은 확인 사항

- 실제 러닝 기록이 충분히 쌓인 계정에서 분석 수치가 사용자 기대와 일치하는지 수동 확인이 필요하다.
- 기록 수가 많아질 경우 현재 클라이언트 집계 방식 대신 별도 Edge Function 통계 API로 분리할 수 있다.
