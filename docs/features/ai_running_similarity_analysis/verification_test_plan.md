# AI Running Similarity Analysis Verification Test Plan

## Scope

러닝 저장 후 Supabase 내장 embedding, PostGIS/수치 유사도 검색, 서버 LLM 리포트 생성, Flutter 결과/분석 화면 표시까지의 변경을 검증한다.

## Quality Goals

- AI 생성은 러닝 저장 후 사용자가 결과 화면 버튼을 눌렀을 때만 실행된다.
- AI 생성 실패가 러닝 저장 성공을 막지 않는다.
- 현재 러닝과 같은 사용자의 과거 러닝만 유사 검색에 사용된다.
- 기존 러닝 데이터는 백필 함수로 embedding을 생성할 수 있다.
- Flutter 화면은 loading, empty, completed, failed 상태를 깨지지 않게 표시한다.
- LLM 모델명은 요구사항대로 `gpt-5.4-mini`를 기본값으로 유지한다.
- 유사도 점수 계산은 극단값에서도 DB 오류 없이 동작한다.
- OpenAI structured output schema는 Responses API strict JSON schema 요구사항을 만족한다.

## Automated Test Plan

```bash
flutter analyze
flutter test test/run_ai_report_service_test.dart
flutter test test/run_result_page_test.dart
flutter test test/statistics_page_test.dart
deno fmt --check supabase/functions/_shared/run-ai.ts supabase/functions/generate-run-ai-report/index.ts supabase/functions/run-ai-report/index.ts supabase/functions/backfill-run-embeddings/index.ts supabase/functions/create-run/index.ts
deno check supabase/functions/generate-run-ai-report/index.ts supabase/functions/run-ai-report/index.ts supabase/functions/backfill-run-embeddings/index.ts supabase/functions/create-run/index.ts
flutter test
```

## Manual QA Plan

- 신규 사용자 첫 러닝 저장 후 결과 화면의 AI 분석 버튼을 눌렀을 때 loading 후 기록 부족 상태가 표시되는지 확인
- 과거 러닝 3개 이상인 사용자에서 AI 분석 버튼을 누른 뒤 AI 요약, 개선점, 다음 목표, 코칭 문구 표시 확인
- `OPENAI_API_KEY`가 없는 환경에서 러닝 저장은 성공하고 AI 리포트는 failed/fallback으로 저장되는지 확인
- `backfill-run-embeddings`를 실행해 기존 러닝의 `run_ai_features`가 채워지는지 확인
- 분석 화면에서 최신 AI 리포트가 표시되는지 확인
- 실제 iPhone에서 AI 분석 버튼을 눌러 `generate-run-ai-report` 200 응답과 `run_ai_reports.status = completed` 저장 확인
- `match_similar_runs`를 원격 DB에서 직접 호출해 유사 기록 3~5개 반환 확인

## Responsive Checklist

- 결과 화면 AI 카드 긴 한국어 문장 overflow 없음
- 분석 화면 최신 AI 분석 카드가 작은 화면에서 겹치지 않음
- 개선점이 3개까지 표시될 때 카드 높이가 자연스럽게 늘어남

## Regression Test Commands

```bash
flutter test
```

원격 Supabase까지 포함하는 검증은 테스트 계정/프로젝트에서 별도로 수행한다. 2026-05-24 기준 테스트 프로젝트 `ifqrceunenzqusppfxgi`와 실제 iPhone에서 주요 AI 생성 흐름을 검증했다.

## Acceptance Criteria

- `flutter analyze` 통과
- 신규 parsing/widget targeted tests 통과
- Deno Edge Function type check 통과
- DB migration은 새 테이블, RPC, index, 백필 대상 구조를 포함
- 원격 migration 적용과 Edge Function 배포 통과
- 실제 기기에서 AI 분석 버튼 실행 후 completed report 저장 확인
- 수동 QA 미수행 항목은 테스트 보고서에 명시

## Release Risk Matrix

| Risk | Impact | Mitigation |
|---|---|---|
| `gpt-5.4-mini` 모델 ID 미지원 | LLM 생성 실패 | `OPENAI_MODEL` secret으로 교체 가능, fallback report 저장 |
| Supabase AI Runtime unavailable | embedding 실패 | feature/report failed 상태 저장, 러닝 저장과 분리 |
| Edge Function timeout | 리포트 지연 | 버튼 실행 중 loading UI와 실패 후 재시도 제공 |
| 기존 데이터 미백필 | 유사 검색 품질 저하 | `backfill-run-embeddings` 배치 실행 |
| pgvector index compatibility | migration 실패 | 테스트 프로젝트에서 migration 선검증 |
| 점수 계산 underflow | 유사도 RPC 500 | `exp()` 입력값 clamp migration 적용 |
| OpenAI strict schema 불일치 | LLM 생성 실패 | nested object `additionalProperties: false`, `strict: true` 적용 |

## Future Test Expansion

- Supabase local DB 기반 RPC SQL 테스트
- OpenAI mock server를 둔 Edge Function integration test
- 실제 원격 Supabase 테스트 계정으로 create-run 후 AI 분석 버튼 실행, report completed까지 확인하는 E2E
