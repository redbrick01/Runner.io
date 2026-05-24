# DESIGN.md 기반 디자인 정비 적용 내역

작성일: 2026-05-24

## 개요

getdesign.md의 디자인 참고 방향을 바탕으로 Flutter 앱 전반의 디자인 기반을 정리했다. 이번 적용은 화면을 완전히 새롭게 갈아엎는 리디자인이 아니라, 기존 밝은 iOS풍 디자인을 유지하면서 반복 UI, 카드 표면, 세그먼트 컨트롤, 메트릭 카드, 공지 카드, 간격 토큰을 공통화하는 정비 작업이다.

적용 기준은 다음과 같다.

- Apple DESIGN.md: 앱 전체의 기본 톤, 밝은 표면, 여백, 설정형 화면 정리
- Nike DESIGN.md: 러닝 결과와 업적 화면의 숫자/성취감 강조
- Airbnb DESIGN.md: 영토 상세, 지도 미리보기, 장소형 카드 구조 정리
- Uber DESIGN.md: 러닝 중 지도 컨트롤과 하단 상태 패널 정돈

## 주요 변경 사항

### 공통 디자인 시스템

- `lib/design/app_design.dart` 추가
- `AppSurface`, `AppSegmentedControl`, `AppMetricCard`, `AppNoticeCard` 추가
- `AppSpacing`, `AppRadii`, `AppTextStyles` 추가
- 고정 크기 버튼과 지도 미리보기에 대응하기 위해 `AppSurface`에 `width`, `height`, `clipBehavior` 지원 추가
- `lib/app_colors.dart`에 보조 색상 토큰 추가
- `lib/main.dart`에 `SnackBarThemeData`, `DialogThemeData` 추가

### 분석/랭킹/기록 계열 화면

대상 파일:

- `lib/main/statistics_page.dart`
- `lib/main/ranking_page.dart`
- `lib/main/run_history_page.dart`
- `lib/main/point_history_page.dart`

변경 내용:

- 반복 구현된 기간 세그먼트 컨트롤을 `AppSegmentedControl`로 교체
- 반복 카드와 빈 상태 카드를 공통 표면으로 정리
- 리스트 패딩을 `AppSpacing.page`로 통일
- 통계 메트릭 카드를 `AppMetricCard`로 정리

### 러닝 결과/지도 화면

대상 파일:

- `lib/main/run_result_page.dart`
- `lib/main/running_map_page.dart`

변경 내용:

- 러닝 결과 화면의 히어로 카드, 주요 기록 카드, 고도 카드, 구간 페이스 카드에 공통 표면 적용
- 핵심 수치의 굵기와 대비를 강화
- 러닝 지도 화면의 상단 현황 배너, 하단 내비게이션, 줌/나침반 버튼, 러닝 중 컨트롤 시트에 공통 표면 적용
- 취소/일시정지/종료 버튼 색상을 `AppColors` 토큰 기반으로 정리

### 영토/업적 화면

대상 파일:

- `lib/main/territory_detail_page.dart`
- `lib/main/achievement_page.dart`

변경 내용:

- 영토 상세의 지도 미리보기, 메트릭 패널, 기여 러닝, 타임라인을 공통 표면으로 정리
- 업적 요약 카드를 더 강한 진행 현황 카드로 정리
- 달성 배지 타일은 더 또렷한 표면과 그림자를 사용하도록 개선
- 오류 공지 카드를 `AppNoticeCard`로 교체

### 프로필/설정 화면

대상 파일:

- `lib/main/my_page.dart`
- `lib/main/profile_edit_page.dart`

변경 내용:

- 마이페이지 프로필 카드, 대표 배지, 메뉴 타일, 로그아웃 버튼을 공통 표면으로 정리
- 프로필 편집 화면의 미리보기 카드, 입력 섹션, 로그아웃 버튼을 공통 표면과 간격 토큰으로 정리
- 기존 입력 힌트와 테스트 대상 문구는 유지

## 검증 결과

다음 명령을 실행해 통과를 확인했다.

```bash
flutter analyze
flutter test
```

최종 결과:

- `flutter analyze`: No issues found
- `flutter test`: 전체 50개 테스트 통과

테스트 중 Supabase가 초기화되지 않은 상태에서 의도적으로 실패 경로를 타는 로그가 출력되지만, 기존 테스트 구조상 예상 가능한 로그이며 테스트는 모두 통과했다.

## 한계 및 후속 작업

이번 작업은 안정성을 우선한 디자인 기반 정비라서, 사용자가 앱을 실행했을 때 큰 시각적 변화가 느껴지지는 않을 수 있다. 더 큰 변화가 필요하다면 다음 단계는 공통화가 아니라 명시적인 비주얼 리디자인으로 진행해야 한다.

추천 후속 작업:

- `RunningMapPage` 하단 러닝 패널을 더 대담한 상태 중심 레이아웃으로 재구성
- `RunResultPage`를 대형 히어로 리포트 스타일로 재배치
- `AchievementPage`를 컬렉션/보드형 배지 화면으로 확장
- 실제 기기 또는 시뮬레이터에서 지도 화면, 러닝 중 패널, 긴 한국어 텍스트 overflow 시각 QA

