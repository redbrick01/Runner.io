# AI Running Similarity Analysis Implementation Report 20260524

## Summary

러닝 저장 후 현재 기록과 유사한 과거 러닝을 검색하고, 서버 LLM 리포트를 Flutter 결과/분석 화면에 표시하기 위한 기능을 구현했다. 이후 Supabase 테스트 프로젝트와 실제 iPhone 기기에서 버튼 기반 AI 분석 생성까지 검증했다.

## Implemented Stages

- Feature plan 작성
- DB migration과 유사도 RPC 추가
- Supabase Edge Function 추가
- 러닝 리포트 화면 AI 분석 버튼 기반 생성 연결
- Flutter AI report service/model 추가
- 결과 화면과 분석 화면 AI 카드 추가
- Targeted tests와 검증 문서 추가
- Supabase 테스트 프로젝트 migration 적용과 Edge Function 배포
- 실제 iPhone 기기 테스트 중 발견된 유사도 underflow와 OpenAI structured output schema 오류 수정

## Changed Files

- `supabase/migrations/20260524003000_add_run_ai_similarity_analysis.sql`
- `supabase/migrations/20260524004500_clamp_run_ai_similarity_scores.sql`
- `supabase/functions/_shared/run-ai.ts`
- `supabase/functions/generate-run-ai-report/index.ts`
- `supabase/functions/run-ai-report/index.ts`
- `supabase/functions/backfill-run-embeddings/index.ts`
- `supabase/functions/create-run/index.ts`
- `lib/services/run_ai_report_service.dart`
- `lib/services/supabase_api.dart`
- `lib/main/run_result_page.dart`
- `lib/main/statistics_page.dart`
- `test/run_ai_report_service_test.dart`
- `test/run_result_page_test.dart`
- `test/statistics_page_test.dart`

## Data Layer Changes

- `run_ai_features`: 러닝 summary text, Supabase `gte-small` embedding, numeric features, route geometry summary 저장
- `run_ai_reports`: LLM/fallback 리포트 저장
- `match_similar_runs`: vector, numeric, PostGIS score를 가중합으로 유사 러닝 3~5개 검색
- `set_run_ai_feature_geometry`: 저장된 run geometry에서 centroid/bbox를 feature row에 반영
- `match_similar_runs` hotfix: 수치/공간 거리 점수 계산에서 `exp()` 입력값을 clamp해 PostgreSQL underflow 방지

## Edge Function Changes

- `generate-run-ai-report`: run summary 생성, embedding 저장, 유사 러닝 검색, OpenAI Responses API 호출, report upsert
- `run-ai-report`: 특정 run 또는 최신 AI 리포트 조회
- `backfill-run-embeddings`: 기존 러닝 embedding batch 생성
- `create-run`: 러닝 저장만 수행하며 AI 생성은 자동 실행하지 않음
- `RunResultPage`: AI 분석 버튼을 눌렀을 때 `generate-run-ai-report` 호출
- OpenAI Responses API structured output schema는 `strict: true`와 `additionalProperties: false`를 사용하도록 수정

## UI Changes

- `RunResultPage`: AI 요약, 개선점, 다음 목표, 코칭 문구 표시
- `RunResultPage`: AI 분석 버튼, 생성 중 loading, 실패 후 재시도 UI 표시
- `StatisticsPage`: 최신 AI 분석 카드 또는 빈 상태 표시
- loading, failed, insufficient data 상태를 표시할 수 있는 카드 추가

## Tests Added Or Updated

- `RunAiReport` parsing test 추가
- 결과 화면 AI 카드 rendering test 추가
- 분석 화면 AI empty state test 보정

## Verification Results

- `flutter analyze`: passed
- `flutter test test/run_ai_report_service_test.dart`: passed
- `flutter test test/run_result_page_test.dart`: passed
- `flutter test test/statistics_page_test.dart`: passed
- `flutter test`: passed, 54 tests
- `deno check` for changed Edge Functions: passed
- Supabase 테스트 프로젝트 migration 적용: passed
- Edge Function deployment: passed
- 기존 러닝 embedding backfill: passed, 전체 대상 49건 feature 생성 완료
- 실제 iPhone 기기 테스트: passed after fixes
  - `generate-run-ai-report` response `200`
  - `run_ai_reports.status = completed`
  - `model = gpt-5.4-mini`
  - AI 요약, 개선점, 다음 목표, 코칭 문구 응답 확인

## Known Limitations

- 로컬 Supabase DB에는 별도 적용하지 않았다. 검증 기준은 테스트 프로젝트 `ifqrceunenzqusppfxgi`이다.
- 기존 러닝의 LLM 리포트 백필은 MVP 범위에서 제외하고 embedding 백필만 제공한다.
- 이전 schema 오류로 `failed` 저장된 개별 리포트는 사용자가 화면에서 재시도하면 새 로직으로 덮어쓴다.

## Follow-Up Items

- 원격 E2E 테스트 자동화 추가
- OpenAI 모델 변경 시 `OPENAI_MODEL` secret으로 교체 후 기기 smoke test 재실행
