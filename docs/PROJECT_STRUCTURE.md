# 프로젝트 구조 상세

작성일: 2026-05-24

이 문서는 Git 업로드 전 코드베이스를 빠르게 이해할 수 있도록 폴더별 책임, 주요 실행 흐름, 데이터 흐름을 정리한다.

## 최상위 구조

| 경로 | 역할 | Git 포함 여부 판단 |
|---|---|---|
| `lib/` | Flutter 앱의 Dart 소스 | 포함 |
| `supabase/` | Supabase config, migrations, Edge Functions | 포함. 단, `.temp/` 제외 |
| `android/` | Android 네이티브 프로젝트와 Kotlin bridge/service | 포함. 단, `.gradle/`, `.kotlin/`, `local.properties` 제외 |
| `ios/` | iOS 네이티브 프로젝트, Live Activity, HealthKit bridge | 포함. 단, `Pods/`, `.symlinks/`, `xcuserdata/` 제외 |
| `macos/`, `linux/`, `windows/` | Flutter desktop 타깃 프로젝트 | 필요한 경우 포함. 생성 캐시는 제외 |
| `web/` | Flutter web shell, manifest, icon | 포함 |
| `test/` | 단위/widget 테스트 | 포함 |
| `integration_test/` | 원격 Supabase API/DB E2E 테스트 | 포함 |
| `docs/` | 개발 보고서, 테스트 계획, 구조 문서 | 포함 여부는 제출 목적에 맞춰 선택 |
| `assets/` | 앱 아이콘 등 정적 리소스 | 포함 |
| `tools/` | 앱 아이콘 생성 Swift 스크립트 | 포함 |
| `res/` | 과거/실험 리소스 자리였으나 실제 리소스가 없어 삭제함 | 제외 |
| `new.dart` | 현재 앱에서 import되지 않는 실험성 Dart 파일이어서 삭제함 | 제외 |

## Flutter 앱 구조

```text
lib/
  main.dart
  app_colors.dart
  login/
  main/
  services/
```

`main.dart`는 앱 부팅과 Supabase 초기화를 담당한다. 세션이 있으면 `RunningMapPage`, 없으면 `LoginPage`로 진입한다.

`app_colors.dart`는 앱 전체에서 공유하는 색상 토큰이다. 새 화면을 만들 때는 하드코딩보다 이 값을 우선 사용한다.

### `lib/login`

로그인과 회원가입 화면이 있다.

- `login_page.dart`: 이메일/비밀번호 로그인, 로그인 성공 시 러닝 지도 화면 이동
- `signup_page.dart`: 이메일/비밀번호 회원가입, 성공 시 로그인 화면으로 복귀

### `lib/main`

주요 사용자 화면과 러닝 계산 엔진이 들어 있다.

| 파일 | 책임 |
|---|---|
| `running_map_page.dart` | 메인 지도, 위치 권한, 러닝 상태, 지도 overlay, 영토/랭킹 로드, 백그라운드 bridge 호출 |
| `run_session_engine.dart` | 위치 샘플 필터링, 거리/속도/페이스/split/고도/일시정지 상태 계산 |
| `run_result_page.dart` | 러닝 종료 결과, 지도 경로, split, 고도 그래프 표시 |
| `run_history_page.dart` | 기간별 러닝 기록 조회와 요약 |
| `point_history_page.dart` | 포인트 획득/차감 이력 조회, 기간 이동 |
| `ranking_page.dart` | 일/주/월/년/전체 랭킹과 내 순위 표시 |
| `territory_detail_page.dart` | 특정 영토 상세, 기여자, 타임라인, 미니맵 |
| `my_page.dart` | 내 프로필 요약, 메뉴, 로그아웃, TTS 테스트 |
| `profile_edit_page.dart` | 닉네임, 색상, 키/몸무게, 비밀번호 수정 |

### `lib/services`

Edge Function과 Supabase Auth 호출을 화면에서 분리한 계층이다.

| 파일 | 책임 |
|---|---|
| `supabase_api.dart` | Supabase URL/key, 인증 header, Edge Function GET/POST 공통 처리 |
| `auth_service.dart` | 로그인, 회원가입, 로그아웃 |
| `run_service.dart` | `create-run` 호출 |
| `run_history_service.dart` | `run-history` 호출과 `RunHistoryEntry` 변환 |
| `point_history_service.dart` | `point-history` 호출 |
| `ranking_service.dart` | `profile-leaderboard` 호출 |
| `profile_service.dart` | 프로필 조회/순위 조회/수정 |
| `territory_service.dart` | 영토 GeoJSON 호출 |
| `running_map_service.dart` | 지도 화면에서 쓰는 프로필/영토 조회 조합 |
| `user_profile_store.dart` | 프로필 snapshot 캐시와 로컬 갱신 |

## 백엔드 구조

```text
supabase/
  config.toml
  seed.sql
  migrations/
  functions/
```

마이그레이션은 PostGIS 기반 지오메트리 처리와 포인트/랭킹 파생 데이터를 담당한다.

주요 테이블:

- `profiles`: 유저 프로필, 색상, 총 포인트, 신체 정보, 랭킹 기준 데이터
- `runs`: 러닝 기록, 거리/시간/포인트/경로/면적
- `run_splits`: 러닝 split 기록
- `territories`: 유저별 점유 영토 geometry, 면적, 기본 포인트, 다음 포인트 처리 시각
- `point_history`: 러닝/영토 등 포인트 이력
- `user_point_daily`: KST 기준 일별 포인트 집계

주요 RPC/trigger:

- `process_run_geometry`: 러닝 경로를 정리하고 loop/area/territory 처리를 수행
- `upsert_or_merge_territory`: 같은 유저의 영토 생성 또는 병합
- `subtract_territory_and_update`: 다른 유저 영토와 겹치는 영역 차감
- `handle_run_points`: 러닝 생성 시 포인트 이력, 프로필 총점, 일별 집계 갱신
- `apply_territory_worker`: 만료된 영토 포인트 배치 처리
- `get_territories_geojson`: 지도 bbox 기준 영토 GeoJSON 조회
- `get_user_info`, `get_profile_rank_count`: 프로필/랭킹 조회

## Edge Functions

| 함수 | 목적 | 인증 |
|---|---|---|
| `create-run` | 러닝 저장, split 저장, DB trigger를 통한 포인트/영토 파생 처리 | Bearer access token |
| `run-history` | 현재 사용자의 러닝 기록과 split 조회 | Bearer access token |
| `point-history` | 현재 사용자의 포인트 이력 조회 | Bearer access token |
| `profile-leaderboard` | 기간별 top/context 랭킹 조회 | Bearer access token |
| `user-ranking` | 현재 사용자 프로필/순위 요약 조회 | Bearer access token |
| `update-profile` | 프로필, 비밀번호 수정 | Bearer access token |
| `territory-geojson` | 지도 bbox 안의 영토 GeoJSON 조회 | anon key 기반 호출 |

## 네이티브 연동

Android:

- `MainActivity.kt`: Flutter MethodChannel `com.example.runner_flutter/live_activity` 처리
- `RunLockScreenService.kt`: foreground service, 위치 추적, 알림 갱신
- `RunActionReceiver.kt`: 알림 action을 앱/서비스로 전달
- `AndroidManifest.xml`: 위치, 백그라운드 위치, foreground service, notification, wake lock 권한과 Google Maps API key 선언

iOS:

- `AppDelegate.swift`: Google Maps API key 등록, Live Activity plugin 등록
- `RunLiveActivityPlugin.swift`, `RunLiveActivityManager.swift`: Flutter MethodChannel과 ActivityKit/HealthKit 연결
- `RunWidgetExtension/`: Live Activity UI와 pause/resume/stop/cancel intent
- `Info.plist`: 위치, HealthKit, Live Activity, background mode 설정

## 데이터 흐름

```text
RunningMapPage
-> Geolocator 위치 stream
-> RunSessionEngine sample filtering/calculation
-> RunService.createRun()
-> Supabase Edge Function create-run
-> runs insert
-> DB trigger/RPC
   -> run_splits insert
   -> point_history insert
   -> user_point_daily upsert
   -> profiles.total_points update
   -> territories geometry update
-> RunResultPage / History / Point / Ranking refresh
```

## 점검 메모

- 현재 프로젝트 루트에는 `.git` 디렉터리가 없어 Git 저장소로 초기화되어 있지 않다.
- `README.md`가 Flutter 기본 템플릿이었으므로 실제 프로젝트 설명으로 교체했다.
- `new.dart`, 빈 `res/`, 미사용 `lib/main/mainlist_page.dart`, `.DS_Store`, 중복 보고서 복사본은 정리했다.
- `ios/Pods`, `macos/Pods`, `android/.gradle`, `android/.kotlin` 같은 생성/로컬 폴더는 `.gitignore`를 보강했으므로 새 Git 초기화 후에는 제외된다.
- API key가 소스에 직접 들어 있다. 공개 저장소라면 키 제한 설정 또는 환경 분리 전략을 적용하는 것이 좋다.
