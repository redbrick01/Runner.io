# Social Final Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 소셜 기능 전체를 실제 유저 관점에서 마감 전 회귀 검토하고, 발견된 결함을 수정한 뒤 검증 증거를 남긴다.

**Architecture:** 검토 범위는 Flutter UI(`SocialPage`, `RunningMapPage`), 클라이언트 서비스(`SocialService`, `CrewService`, `TerritoryService`), Supabase Edge Functions(`social-friends`, `social-crews`, `territory-geojson`), 관련 테스트로 나눈다. UI 흐름은 위젯 테스트로, 모델/파서/헬퍼는 단위 테스트로, Edge Function 타입/헬퍼는 Deno로 검증한다.

**Tech Stack:** Flutter/Dart, Supabase Flutter, Supabase Edge Functions on Deno, Flutter widget tests, Deno tests.

---

### Task 1: 검토 범위 고정

**Files:**
- Inspect: `lib/main/social_page.dart`
- Inspect: `lib/services/social_service.dart`
- Inspect: `lib/services/crew_service.dart`
- Inspect: `lib/services/territory_service.dart`
- Inspect: `lib/main/running_map_page.dart`
- Inspect: `supabase/functions/social-friends/index.ts`
- Inspect: `supabase/functions/social-crews/index.ts`
- Inspect: `supabase/functions/territory-geojson/index.ts`
- Inspect: `test/social_page_test.dart`
- Inspect: `test/social_service_model_test.dart`
- Inspect: `test/crew_service_model_test.dart`
- Inspect: `test/running_map_page_test.dart`
- Inspect: `test/running_map_crew_contribution_test.dart`

- [x] **Step 1: 소셜 관련 파일과 테스트를 검색한다**

Run:
```bash
rg -n "SocialPage|SocialService|CrewService|TerritoryScope|RankingScope|social-friends|social-crews|friend|crew" lib test supabase/functions supabase/migrations
```

Expected: 친구, 크루, 지도 스코프, 랭킹 연동 파일 목록이 나온다.

- [x] **Step 2: 현재 변경 범위를 확인한다**

Run:
```bash
git diff --stat -- lib/main/social_page.dart lib/main/running_map_page.dart test/social_page_test.dart test/running_map_page_test.dart supabase/functions/social-crews/index.ts supabase/functions/territory-geojson/index.ts
```

Expected: 소셜/지도/Edge Function 관련 파일만 이번 검토 범위로 잡힌다.

### Task 2: 친구 기능 회귀 검토

**Files:**
- Modify if needed: `lib/main/social_page.dart`
- Test: `test/social_page_test.dart`
- Test: `test/social_service_model_test.dart`
- Inspect: `supabase/functions/social-friends/index.ts`

- [x] **Step 1: 친구 코드 표시/복사, 코드 검색, 요청 전송, 받은 요청, 친구 목록, 친구 랭킹 시나리오를 점검한다**

Checklist:
```text
친구 코드가 있으면 복사 가능
친구 코드가 없으면 "발급 전"과 안내 문구 표시
친구 검색 입력이 비어 있으면 조회/요청 차단
조회 성공 후 요청 전송 가능
로딩 실패 시 Supabase/네트워크/인증 오류가 유저 문구로 표시
친구 목록과 랭킹은 메인 탭에서 바로 확인 가능
친구 관리성 작업은 친구 관리 화면으로 분리
```

- [x] **Step 2: 위젯 테스트를 실행한다**

Run:
```bash
flutter test test/social_page_test.dart
```

Expected: All tests passed.

### Task 3: 크루 기능 회귀 검토

**Files:**
- Modify if needed: `lib/main/social_page.dart`
- Modify if needed: `lib/services/crew_service.dart`
- Modify if needed: `supabase/functions/social-crews/index.ts`
- Test: `test/social_page_test.dart`
- Test: `test/crew_service_model_test.dart`
- Test: `supabase/functions/social-crews/helpers.test.ts`

- [x] **Step 1: 크루 생성, 공개 크루 검색, 가입, 나가기, 기본 크루 설정, 크루 랭킹, 멤버 랭킹 시나리오를 점검한다**

Checklist:
```text
크루명 2자 미만 생성 차단
중복 크루명은 입력값 유지 후 명확한 오류 표시
생성 중 멤버십/기본 크루 설정 실패 시 생성 크루 보상 롤백
가입/나가기/기본 설정 후 내 크루와 상세가 새로고침됨
선택된 크루를 나가면 다음 유효 크루 상세로 이동
가입하지 않은 크루의 멤버 랭킹은 숨김
```

- [x] **Step 2: Flutter 모델/화면 테스트를 실행한다**

Run:
```bash
flutter test test/social_page_test.dart test/crew_service_model_test.dart
```

Expected: All tests passed.

- [x] **Step 3: Edge Function 타입/헬퍼 테스트를 실행한다**

Run:
```bash
deno check supabase/functions/social-crews/index.ts
deno test supabase/functions/social-crews/helpers.test.ts
```

Expected: Type check passes and helper tests pass.

### Task 4: 지도/랭킹 소셜 연동 검토

**Files:**
- Modify if needed: `lib/main/running_map_page.dart`
- Modify if needed: `lib/main/ranking_page.dart`
- Modify if needed: `lib/services/territory_service.dart`
- Inspect: `supabase/functions/territory-geojson/index.ts`
- Test: `test/running_map_page_test.dart`
- Test: `test/running_map_crew_contribution_test.dart`

- [x] **Step 1: 메인 지도 토글과 데이터 스코프를 검증한다**

Checklist:
```text
토글은 개인/크루만 표시
친구 토글 미표시
토글 문구에 경쟁 미표시
개인 토글은 개인전 기본 맵 요청
크루 토글은 scope=crew 요청
크루 토글 시 상단 배너 랭킹/포인트/면적은 크루 기준
소셜 페이지 이동 시 위치 경고 스낵바는 사라짐
```

- [x] **Step 2: 지도 관련 테스트를 실행한다**

Run:
```bash
flutter test test/running_map_page_test.dart test/running_map_crew_contribution_test.dart
```

Expected: All tests passed.

### Task 5: 최종 검증

**Files:**
- Test: all files above

- [x] **Step 1: Flutter 정적 분석을 실행한다**

Run:
```bash
flutter analyze lib/main/social_page.dart lib/main/running_map_page.dart lib/services/social_service.dart lib/services/crew_service.dart lib/services/territory_service.dart test/social_page_test.dart test/social_service_model_test.dart test/crew_service_model_test.dart test/running_map_page_test.dart test/running_map_crew_contribution_test.dart
```

Expected: No issues found.

- [x] **Step 2: 소셜 관련 Flutter 테스트를 실행한다**

Run:
```bash
flutter test test/social_page_test.dart test/social_service_model_test.dart test/crew_service_model_test.dart test/running_map_page_test.dart test/running_map_crew_contribution_test.dart
```

Expected: All tests passed.

- [x] **Step 3: Supabase 함수 검증을 실행한다**

Run:
```bash
deno check supabase/functions/social-friends/index.ts supabase/functions/social-crews/index.ts supabase/functions/territory-geojson/index.ts
deno test supabase/functions/social-friends/helpers.test.ts supabase/functions/social-crews/helpers.test.ts supabase/functions/territory-geojson/helpers.test.ts
```

Expected: Type check passes and all helper tests pass.

- [x] **Step 4: 최종 diff를 검토한다**

Run:
```bash
git diff -- lib/main/social_page.dart lib/main/running_map_page.dart test/social_page_test.dart test/running_map_page_test.dart supabase/functions/social-crews/index.ts supabase/functions/territory-geojson/index.ts
```

Expected: 변경사항이 소셜 마감 범위 안에 있고, 불필요한 리팩터나 unrelated change가 없다.
