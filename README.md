# Runner Flutter

Runner Flutter는 GPS 러닝 기록을 기반으로 이동 경로, 거리, 페이스, 칼로리, 고도, 포인트, 개인 영토, 랭킹을 제공하는 Flutter 앱입니다. 클라이언트는 Flutter로 작성되어 Android, iOS, Web, Desktop 타깃을 포함하고, 서버 측 데이터 처리는 Supabase PostgreSQL/PostGIS, Auth, Edge Functions를 사용합니다.

## 핵심 기능

- 이메일 기반 회원가입, 로그인, 로그아웃
- Google Maps 기반 현재 위치 표시와 러닝 경로 추적
- 러닝 시작, 카운트다운, 일시정지, 재개, 종료, 취소
- 거리, 시간, 평균 페이스, 평균 속도, 칼로리, 고도 상승량, 1km split 계산
- 러닝 종료 후 경로 저장, 결과 리포트, split/고도/지도 시각화
- PostGIS 기반 개인 영토 생성, 병합, 면적 계산, 영토 포인트 누적
- 일/주/월/년/전체 랭킹과 내 주변 순위 조회
- 포인트 이력, 러닝 기록, 프로필 수정
- Android foreground service/잠금화면 알림, iOS Live Activity/HealthKit 기반 백그라운드 러닝 보조

## 기술 스택

| 영역 | 사용 기술 |
|---|---|
| App | Flutter, Dart, Material 3 |
| Map/Location | google_maps_flutter, geolocator |
| Backend | Supabase Auth, PostgreSQL, PostGIS, Edge Functions |
| Native Android | Kotlin, foreground service, notification action |
| Native iOS | Swift, ActivityKit Live Activity, HealthKit workout session |
| Test | flutter_test, integration_test, Supabase HTTP E2E |

## 빠른 시작

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Supabase 로컬 환경을 사용할 경우:

```bash
supabase start
supabase db reset
supabase functions serve
```

현재 앱과 E2E 테스트는 원격 Supabase 프로젝트 `ifqrceunenzqusppfxgi`를 바라보도록 상수로 설정되어 있습니다. GitHub 공개 저장소에 올리기 전에는 Supabase URL, anon key, Google Maps API key의 노출 정책과 제한 설정을 반드시 확인하세요. anon key는 공개 클라이언트 키이지만, 도메인/패키지 제한과 RLS/Edge Function 권한 설계가 함께 맞아야 안전합니다.

Google Maps API key는 Git에 커밋하지 않습니다.

- Android: `android/local.properties`에 `GOOGLE_MAPS_API_KEY=...`를 추가하거나 빌드 환경변수 `GOOGLE_MAPS_API_KEY`를 설정합니다.
- iOS: Xcode build setting 또는 로컬 xcconfig에서 `GOOGLE_MAPS_API_KEY`를 설정합니다.

## 주요 문서

- [프로젝트 구조](docs/PROJECT_STRUCTURE.md)
- [Git 업로드 전 체크리스트](docs/PRE_GIT_CHECKLIST.md)
- [테스트 계획 및 결과](docs/test_plan_and_results.md)
- [Flutter 앱 구조](lib/README.md)
- [Supabase 백엔드 구조](supabase/README.md)
- [테스트 구조](test/README.md)

## 프로젝트 구조 요약

```text
lib/                  Flutter 앱 소스
  login/              로그인/회원가입 화면
  main/               러닝, 지도, 기록, 랭킹, 프로필 화면과 러닝 엔진
  services/           Supabase Auth/Edge Function 호출 계층과 프로필 캐시

supabase/
  functions/          Edge Functions
  migrations/         PostgreSQL/PostGIS schema, trigger, RPC migration
  seed.sql            로컬 seed 진입점

android/, ios/        모바일 네이티브 러닝 백그라운드/알림/지도 설정
test/                 Flutter unit/widget tests
integration_test/     Supabase API/DB E2E test
docs/                 보고서와 운영/구조 문서
tools/                보조 스크립트
assets/               앱 아이콘 등 정적 리소스
```

## 주요 실행 흐름

```text
앱 실행
-> Supabase 초기화
-> 현재 세션 확인
-> 세션 없음: LoginPage
-> 세션 있음: RunningMapPage
-> 위치 권한/지도/프로필/영토/랭킹 로드
-> 러닝 시작 및 위치 샘플 수집
-> RunSessionEngine에서 거리/속도/split/고도 계산
-> 러닝 종료 시 create-run Edge Function 호출
-> runs, run_splits, point_history, user_point_daily, territories 갱신
-> RunResultPage, 기록, 포인트 이력, 랭킹에 반영
```

## 테스트

전체 Flutter 테스트:

```bash
flutter test
```

러닝 엔진 단위 테스트:

```bash
flutter test test/run_session_engine_test.dart
```

원격 Supabase E2E 테스트:

```bash
flutter test integration_test/runner_api_e2e_test.dart \
  --dart-define=RUNNER_E2E_EMAIL=your-test-user@example.com \
  --dart-define=RUNNER_E2E_PASSWORD=your-password
```

`RUNNER_E2E_EMAIL`과 `RUNNER_E2E_PASSWORD`를 생략하면 테스트가 고유 이메일로 신규 사용자를 생성합니다. 원격 DB에 테스트 데이터가 남을 수 있으니 운영 프로젝트에서는 전용 테스트 계정 또는 별도 테스트 프로젝트를 권장합니다.

## Git 업로드 전 주의사항

- 이 디렉터리는 현재 Git 저장소로 초기화되어 있지 않았습니다. 업로드 전 `git init` 또는 원격 저장소 clone 위치를 확인하세요.
- `.gitignore`는 Flutter build 산출물, Android/iOS/macOS 로컬 캐시, CocoaPods, Supabase local metadata를 제외하도록 보강되어 있습니다.
- 이미 생성되어 있는 `ios/Pods`, `macos/Pods`, `.gradle`, `.kotlin` 같은 로컬 생성 폴더는 Git 초기화 전이라면 무시 규칙 적용 후 올라가지 않습니다.
- `new.dart`, 빈 `res/`, `lib/main/mainlist_page.dart`, `.DS_Store`, 중복 보고서 복사본은 정리했습니다.
- `docs/` 안의 남은 `.docx` 보고서 파일은 제출 산출물 기준으로 유지했습니다.
