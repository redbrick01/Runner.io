# AI Running Similarity Analysis Test Report 20260524

## Summary

AI 러닝 유사도 분석 기능의 Flutter parsing/UI, Supabase Edge Function 정적 검증, Supabase 테스트 프로젝트 원격 검증, 실제 iPhone 기기 QA를 수행했다. 기기 테스트 중 발견한 서버 오류 2건을 수정하고 재검증했다.

## Test Environment

- Date: 2026-05-24
- Workspace: `/Users/yw0410/Desktop/Project/runner_flutter`
- Flutter/Dart: local project toolchain
- Edge Function checker: Deno
- Supabase project: `ifqrceunenzqusppfxgi`
- Device: iPhone, iOS 26.3.1
- LLM model: `gpt-5.4-mini`
- Embedding model: Supabase built-in `gte-small`

## Commands Run

```bash
dart format lib/services/supabase_api.dart lib/services/run_ai_report_service.dart lib/main/run_result_page.dart lib/main/statistics_page.dart test/run_ai_report_service_test.dart test/run_result_page_test.dart test/statistics_page_test.dart
deno fmt supabase/functions/_shared/run-ai.ts supabase/functions/generate-run-ai-report/index.ts supabase/functions/run-ai-report/index.ts supabase/functions/backfill-run-embeddings/index.ts supabase/functions/create-run/index.ts
flutter analyze
flutter test test/run_ai_report_service_test.dart
flutter test test/statistics_page_test.dart
flutter test test/run_result_page_test.dart
deno check supabase/functions/generate-run-ai-report/index.ts supabase/functions/run-ai-report/index.ts supabase/functions/backfill-run-embeddings/index.ts supabase/functions/create-run/index.ts
flutter test
supabase db push
supabase functions deploy generate-run-ai-report
flutter run -d 00008150-001225DC1186401C
```

## Command Results

| Command | Result |
|---|---|
| `dart format ...` | Passed |
| `deno fmt ...` | Passed |
| `flutter analyze` | Passed, no issues found |
| `flutter test test/run_ai_report_service_test.dart` | Passed, 2 tests |
| `flutter test test/statistics_page_test.dart` | Passed, 2 tests |
| `flutter test test/run_result_page_test.dart` | Passed, 5 tests |
| `deno check ...` | Passed after allowing dependency fetch |
| `flutter test` | Passed, 54 tests |
| `supabase db push` | Passed, migration `20260524004500_clamp_run_ai_similarity_scores.sql` applied |
| `supabase functions deploy generate-run-ai-report` | Passed |
| `flutter run -d 00008150-001225DC1186401C` | Passed, app launched on physical iPhone |

## Remote And Device QA Results

| Scenario | Result | Notes |
|---|---|---|
| Connected device discovery | Passed | iPhone, macOS, Chrome detected |
| App launch on iPhone | Passed | Supabase init completed |
| Existing report fetch | Passed | `run-ai-report` returned `200`; no report when none exists |
| AI analysis button call | Initially failed, then passed | Button called `generate-run-ai-report` from device |
| Similarity RPC | Fixed | Initial error: `Similarity search failed: value out of range: underflow` |
| OpenAI structured output | Fixed | Initial error: invalid JSON schema for nested object |
| Final AI report generation | Passed | `generate-run-ai-report` returned `200` with Korean summary |
| DB persistence | Passed | `run_ai_reports.status = completed`, `model = gpt-5.4-mini` |

Final verified row:

- `run_id`: 138
- `status`: `completed`
- `similar_run_ids`: `[141, 139, 130, 129, 131]`
- `summary`: 한국어 AI 요약 저장 확인
- `next_goal`: `언덕 2km 이지런`
- `error_message`: `null`

## Verification Against Plan

- Flutter AI report model parsing verified.
- Run result page AI card rendering verified.
- Statistics page AI empty state and existing summary behavior verified.
- Edge Function TypeScript checked with Deno.
- `flutter analyze` verified the Dart code.
- Full Flutter test suite passed.
- Supabase remote migration and Edge Function deployment verified.
- Physical iPhone AI report generation verified.

## Manual QA Status

Completed for the AI analysis button flow on a physical iPhone.

Remaining manual QA:

- Repeat on Android physical device.
- Re-run failed historical reports from the app when needed.

## Acceptance Criteria Result

Automated acceptance criteria passed for local Dart and Edge Function static checks. Remote DB/API and physical iPhone acceptance criteria also passed after the underflow and schema fixes.

## Risk Assessment After Testing

- Supabase project compatibility for `vector` extension and `ivfflat` index was verified in the test project.
- `gpt-5.4-mini` was used successfully through the deployed Edge Function.
- Supabase built-in `gte-small` embedding is English-oriented; numeric and PostGIS scoring were included to reduce dependence on text embedding quality.
- Very large numeric or spatial deltas are now clamped before `exp()` scoring to prevent PostgreSQL underflow.

## Final Result

Local implementation checks, remote Supabase integration, and physical iPhone AI analysis QA passed.
