# AI Running Similarity Analysis Plan

## Product Goal

러닝 저장 후 사용자가 러닝 리포트 화면에서 AI 분석 버튼을 누르면 현재 기록과 유사한 과거 러닝 3~5개를 찾아 서버 LLM에 전달하고, 결과/분석 화면에서 사용자가 바로 이해할 수 있는 개인화 비교 리포트를 제공한다.

핵심 경험은 다음과 같다.

- 저장된 현재 러닝을 과거 러닝과 비교해 AI 요약을 생성한다.
- 사용자가 개선점, 다음 목표, 짧은 코칭 문구를 결과 화면과 분석 화면에서 확인한다.
- 유사 러닝 검색은 Supabase Edge Function에서 PostGIS 공간 유사도와 수치 벡터 유사도를 함께 사용한다.
- 임베딩은 Supabase Edge Runtime 내장 embedding 모델을 사용한다. 구현 기준 모델은 `gte-small`로 계획한다.
- 서버 LLM은 요구사항 기준 `gpt-5.4-mini`를 사용한다고 명시한다.
- 기존에 이미 저장된 러닝 데이터도 별도 백필 과정으로 임베딩한다.

## Current Baseline

현재 러닝 저장 흐름은 다음과 같다.

```text
RunResultPage / RunningMapPage
-> RunService.createRun()
-> SupabaseApi.postFunctionJson('create-run')
-> supabase/functions/create-run
-> runs, run_splits 저장
-> DB trigger/RPC가 포인트, 영토, 일별 포인트 갱신
```

현재 분석 화면은 `StatisticsPage`에서 `RunHistoryService`와 `StatisticsService`를 이용해 기간별 거리, 시간, 횟수, 평균 페이스, 포인트, 최근 7일 거리, 개인 기록을 클라이언트 집계로 표시한다. AI 분석 API나 AI 리포트 저장 테이블은 아직 없다.

현재 주요 데이터는 다음 테이블에 있다.

- `runs`: 거리, 시간, 평균 페이스, 칼로리, 포인트, 경로 geometry, 점령 면적
- `run_splits`: split별 거리, 시간, 페이스, 속도, 고도 상승, split 경로
- `profiles`: 사용자 기본 정보와 누적 포인트

## Success Criteria

- 새 러닝 저장 후 서버에서 현재 러닝 임베딩을 생성하고 저장한다.
- 서버에서 같은 사용자의 과거 러닝 중 현재 러닝과 유사한 기록 3~5개를 검색한다.
- 검색 기준은 경로/지역의 공간 유사도와 거리, 시간, 페이스, 상승, 칼로리, 면적, split 패턴 등 수치 특징을 함께 반영한다.
- LLM 호출은 클라이언트가 아니라 Supabase Edge Function에서만 수행한다.
- LLM 결과는 구조화 JSON으로 저장되고 Flutter 화면에서 안정적으로 표시된다.
- 결과 화면에는 AI 요약, 개선점, 다음 목표, 코칭 문구가 표시된다.
- 분석 화면에는 최근 AI 리포트 또는 선택한 러닝의 AI 리포트가 표시된다.
- 이미 저장된 기존 러닝도 백필 작업을 통해 임베딩 대상에 포함된다.
- LLM 실패, 임베딩 실패, 유사 기록 부족 상황에서도 러닝 저장 자체는 실패하지 않는다.

## Metric And Data Definitions

### Run Summary

LLM과 임베딩 입력에 사용할 현재 러닝 요약은 다음 필드를 기준으로 한다.

- `run_id`
- `started_at`, `ended_at`
- `distance_m`
- `duration_s`
- `avg_pace_s_per_km`
- `avg_speed_mps`
- `calories`
- `point`
- `area_m2`
- `total_ascent_m`
- `split_count`
- `split_pace_series`
- `split_ascent_series`
- `route_bbox`
- `route_centroid`
- `route_length_m`
- `weekday`
- `hour_of_day`

### Numeric Feature Vector

Postgres에서 정규화 가능한 수치 특징을 별도 컬럼 또는 JSON으로 저장한다.

초기 MVP 벡터 후보:

```text
[
  distance_km_z,
  duration_min_z,
  avg_pace_s_per_km_z,
  avg_speed_mps_z,
  calories_z,
  total_ascent_m_z,
  area_m2_z,
  split_count_z,
  pace_variance_z,
  positive_split_score_z
]
```

정규화 기준은 사용자별 통계가 충분하면 사용자별 평균/표준편차, 부족하면 전체 기본 스케일을 사용한다.

### Text Embedding Input

Supabase 내장 embedding 모델은 텍스트 입력을 벡터화하므로, 러닝 요약을 안정적인 문장/키-값 형태로 변환한다.

예시:

```text
distance=5.02km duration=1820s avg_pace=362s/km ascent=38m calories=281 area=12000m2 splits=5 pace_series=360,365,370,358,355 route_centroid=37.5,127.0 weekday=sunday hour=7
```

### Similarity Score

MVP의 최종 유사도 점수는 가중합으로 계산한다.

```text
total_score =
  embedding_score * 0.45 +
  numeric_score * 0.35 +
  spatial_score * 0.20
```

가중치는 테스트 데이터와 사용자 체감 결과를 보고 조정한다. 유사 기록이 3개 미만이면 threshold를 완화하되, 같은 `run_id`와 현재 저장 직후의 자기 자신은 제외한다.

## Proposed UX

### Run Result Page

러닝 저장 후 결과 화면 상단 기록 영역 아래에 AI 리포트 섹션을 추가한다.

상태:

- 생성 중: 저장은 완료되었고 AI 리포트를 생성 중인 상태
- 완료: AI 요약, 개선점, 다음 목표, 코칭 문구 표시
- 실패: 짧은 안내와 재시도 버튼 표시
- 기록 부족: 비교 가능한 과거 러닝이 부족하다는 안내와 기본 코칭 표시

표시 항목:

- AI 요약: 1~2문장
- 개선점: 최대 3개 bullet
- 다음 목표: 거리, 페이스, 시간, 빈도 중 하나 이상의 구체 목표
- 코칭 문구: 짧고 긍정적인 한 문장
- 비교 기준: 유사 기록 개수와 대표 비교 지표

### Statistics Page

기존 기간별 통계 아래에 "AI 분석" 섹션을 추가한다.

표시 방식:

- 가장 최근 AI 리포트 요약
- 최근 리포트 목록 또는 최근 3개 러닝의 AI 코칭
- 리포트가 없으면 러닝 리포트 화면에서 AI 분석 버튼으로 생성할 수 있다는 빈 상태

MVP에서는 상세 AI 분석 화면을 새로 만들지 않고, 결과 화면과 분석 화면의 카드 UI로 제한한다.

## Data And API Changes

### Database

신규 migration을 추가한다.

후보 테이블:

```sql
create extension if not exists vector;

create table public.run_ai_features (
  run_id bigint primary key references public.runs(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id),
  embedding vector(384),
  numeric_features jsonb not null default '{}'::jsonb,
  summary_text text not null,
  total_ascent_m double precision,
  pace_variance double precision,
  route_centroid public.geometry(Point, 4326),
  route_bbox public.geometry(Polygon, 4326),
  embedding_model text not null default 'gte-small',
  embedding_status text not null default 'pending',
  embedded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

```sql
create table public.run_ai_reports (
  run_id bigint primary key references public.runs(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id),
  similar_run_ids bigint[] not null default '{}',
  model text not null default 'gpt-5.4-mini',
  summary text not null,
  improvements jsonb not null default '[]'::jsonb,
  next_goal jsonb not null default '{}'::jsonb,
  coaching_message text not null,
  comparison jsonb not null default '{}'::jsonb,
  status text not null default 'completed',
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

권장 인덱스:

- `run_ai_features_user_id_idx`
- `run_ai_features_embedding_hnsw_idx` 또는 프로젝트 Postgres 버전에 맞는 vector index
- `runs_path_geom_gix`
- `run_ai_features_route_centroid_gix`
- `run_ai_reports_user_created_idx`

### Postgres RPC

유사 러닝 검색 RPC를 추가한다.

```text
match_similar_runs(
  p_user_id uuid,
  p_run_id bigint,
  p_embedding vector(384),
  p_numeric_features jsonb,
  p_limit int default 5
)
```

역할:

- 같은 사용자의 과거 러닝만 검색한다.
- 현재 `run_id`를 제외한다.
- vector distance, numeric distance, PostGIS distance/intersection score를 계산한다.
- 최종 점수 기준 3~5개를 반환한다.

### Edge Functions

신규 또는 확장 후보:

- `create-run`: 러닝 저장만 담당하고 AI 분석은 자동 실행하지 않는다.
- `generate-run-ai-report`: 특정 `run_id`의 임베딩, 유사 기록 검색, LLM 리포트 생성을 담당한다.
- `run-ai-report`: Flutter에서 특정 러닝 또는 최신 리포트를 조회한다.
- `backfill-run-embeddings`: 기존 러닝의 summary/features/embedding을 배치로 생성한다.

MVP 권장 구조:

```text
create-run
-> runs/run_splits 저장
-> RunResultPage AI 분석 버튼
-> generate-run-ai-report 호출
-> run_ai_features upsert
-> match_similar_runs RPC
-> OpenAI LLM 호출
-> run_ai_reports upsert
```

러닝 저장 응답은 기존 호환성을 유지한다. AI 분석 생성은 사용자가 버튼을 눌렀을 때 별도 API 응답으로 처리한다.

### LLM Contract

LLM은 서버에서만 호출한다.

- 모델: `gpt-5.4-mini`
- API key: Supabase Edge Function secret으로만 저장
- 응답 형식: JSON object
- 언어: 한국어
- 톤: 짧고 친근한 러닝 코치
- 금지: 의료 진단, 과도한 체중/건강 판단, 부상 확정 표현

구조화 응답 예시:

```json
{
  "summary": "오늘은 최근 비슷한 5km 러닝보다 후반 페이스 유지가 좋아졌어요.",
  "improvements": [
    "초반 1km 페이스가 다소 빠르게 시작돼 중반에 흔들릴 수 있어요.",
    "상승 구간 이후 회복 페이스를 조금 더 일정하게 가져가면 좋아요."
  ],
  "next_goal": {
    "type": "pace",
    "label": "다음 5km 평균 페이스 5초 단축",
    "target_pace_s_per_km": 357
  },
  "coaching_message": "지금처럼 후반을 살리는 리듬이면 다음 기록도 충분히 노려볼 만해요.",
  "comparison": {
    "similar_run_count": 4,
    "distance_delta_m": 80,
    "pace_delta_s_per_km": -7
  }
}
```

모델 ID 주의:

- 요청사항에는 `gpt-5.4-mini`를 명시한다.
- 구현 직전 OpenAI 공식 모델 목록에서 실제 사용 가능한 모델 ID를 확인한다.
- 만약 `gpt-5.4-mini`가 사용 불가하면 제품/개발 결정 기록에 대체 모델 승인 여부를 남긴다.

## Existing Data Backfill Plan

기존 저장 러닝 임베딩은 별도 배치로 처리한다.

1. migration 배포 후 `run_ai_features`에 없는 `runs` 목록을 조회한다.
2. `runs`와 `run_splits`를 join해 summary text와 numeric features를 만든다.
3. Supabase Edge Runtime 내장 embedding 모델 `gte-small`로 embedding을 생성한다.
4. `run_ai_features`에 upsert한다.
5. 실패한 run은 `embedding_status='failed'`와 에러 메시지를 남기고 재시도 가능하게 한다.
6. 백필 완료 후 샘플 사용자 기준 유사 검색 결과가 3~5개 나오는지 확인한다.

운영 안전장치:

- 한 번에 처리할 batch size는 20~50개로 시작한다.
- Edge Function timeout을 고려해 cursor 기반 반복 호출을 사용한다.
- 운영 DB 백필 전 테스트 프로젝트 또는 백업에서 먼저 검증한다.
- LLM 리포트 백필은 비용이 크므로 MVP에서는 신규 저장 러닝부터 생성하고, 기존 러닝은 embedding만 먼저 백필한다.

## Development Phases

### Phase 1. Discovery And Contract

- 현재 `create-run`, `run-history`, `StatisticsPage`, `RunResultPage` 데이터 흐름 확인
- AI 리포트 DTO와 Flutter 표시 모델 정의
- Supabase 내장 embedding API 사용 방식 확인
- OpenAI `gpt-5.4-mini` 실제 모델 ID 확인

완료 기준:

- DB schema 초안과 Edge Function 응답 contract가 확정된다.
- 실패/재시도 정책이 문서화된다.

### Phase 2. DB Migration And Similarity RPC

- `vector` extension 활성화 migration 추가
- `run_ai_features`, `run_ai_reports` 추가
- PostGIS/vector/numeric 유사도 RPC 추가
- SQL 단위 검증용 seed 또는 fixture 작성

완료 기준:

- 샘플 데이터에서 현재 러닝 제외, 같은 사용자 한정, 3~5개 정렬 반환이 검증된다.

### Phase 3. Feature Extraction And Embedding

- Edge Function 공통 유틸로 run summary 생성
- split 기반 상승/페이스 편차 계산
- Supabase 내장 `gte-small` embedding 생성
- AI 분석 버튼 실행 시 feature upsert 구현
- 기존 러닝 백필 함수 구현

완료 기준:

- 신규/기존 러닝 모두 `run_ai_features`에 embedding과 summary가 저장된다.

### Phase 4. AI Report Generation

- `generate-run-ai-report` Edge Function 구현
- 유사 러닝 3~5개와 현재 러닝 요약을 LLM prompt에 주입
- `gpt-5.4-mini` 구조화 JSON 응답 파싱
- `run_ai_reports` upsert
- LLM 실패 시 저장 성공 흐름과 분리

완료 기준:

- AI 리포트가 저장되고 조회 API로 동일한 JSON contract를 반환한다.

### Phase 5. Flutter Service And State

- `RunAiReportService` 추가
- `RunAiReport` model 추가
- `RunService.createRun()` 응답에서 AI 상태 처리
- 결과 화면에서 polling 또는 재조회 구현
- 분석 화면에서 최신 AI 리포트 조회 구현

완료 기준:

- 결과 화면과 분석 화면이 loading/completed/failed/empty 상태를 모두 표시한다.

### Phase 6. UI Integration

- `RunResultPage`에 AI 분석 카드 추가
- `StatisticsPage`에 최근 AI 분석 섹션 추가
- 기존 `AppSurface`, `AppNoticeCard`, `AppMetricCard` 스타일 유지
- 긴 문장, 작은 화면, 빈 상태 UI 검증

완료 기준:

- AI 요약, 개선점, 다음 목표, 코칭 문구가 모바일 화면에서 겹침 없이 표시된다.

### Phase 7. Verification And Documentation

- Edge Function 정적 검증
- Flutter unit/widget test 추가
- integration test 확장
- 수동 QA 시나리오 작성
- 구현 완료 후 temporary report와 final implementation report 작성
- `docs/simple_patches/PROJECT_STRUCTURE.md`, `README.md`, `docs/README.md` 갱신

완료 기준:

- targeted test와 수동 QA 결과가 문서화된다.

## MVP Scope

MVP에 포함:

- Supabase 내장 `gte-small` embedding 기반 run feature 저장
- 기존 러닝 embedding 백필
- vector/numeric/PostGIS 혼합 유사 검색
- 새 러닝 저장 후 사용자가 결과 화면에서 AI 분석 버튼을 눌렀을 때 리포트 생성
- 결과 화면 AI 카드
- 분석 화면 최신 AI 리포트 카드
- LLM 모델 요구사항 `gpt-5.4-mini` 명시
- 실패 상태와 재시도 API

MVP에서 제외:

- 모든 기존 러닝의 LLM 리포트 일괄 생성
- 사용자별 목표 설정 UI
- 훈련 계획 캘린더 자동 생성
- push notification 기반 리포트 완료 알림
- 여러 LLM 모델 A/B 테스트
- 장기 추세 기반 부상 위험 예측

## Test Plan

### Automated Tests

- SQL/RPC
  - 같은 사용자 러닝만 반환
  - 현재 run 제외
  - 유사도 순 정렬
  - 유사 기록 0개, 1~2개, 3~5개 케이스
- Edge Function
  - 인증 누락/잘못된 토큰
  - run_id 누락/권한 없는 run_id
  - embedding 생성 성공/실패
  - LLM JSON parse 성공/실패
  - 기존 create-run 응답 호환성
- Flutter
  - `RunAiReport` parsing
  - 결과 화면 loading/completed/failed/empty 렌더링
  - 분석 화면 최신 리포트 렌더링
  - 긴 한국어 문구 overflow 방지
- Integration
  - create-run 후 AI 분석 버튼 실행, loading/completed 조회
  - backfill 후 유사 러닝 검색

### Manual QA

- 신규 사용자 첫 러닝 저장
- 과거 기록 2개 이하인 사용자
- 과거 기록 5개 이상인 사용자
- 같은 코스를 반복한 사용자
- 거리와 코스는 비슷하지만 페이스가 다른 사용자
- LLM secret 미설정 환경
- 네트워크 실패 또는 Edge Function timeout

## Risks And Decisions

| 항목 | 리스크 | 대응 |
| --- | --- | --- |
| LLM 모델 ID | `gpt-5.4-mini`가 실제 API에서 사용 불가할 수 있음 | 구현 전 공식 모델 목록 확인, env 기반 모델명 주입, 대체 모델 승인 기록 |
| Edge Function timeout | 버튼 실행 후 embedding+LLM이 오래 걸릴 수 있음 | 화면 loading 상태와 재시도 제공, 저장 성공과 AI 생성 분리 |
| 비용 | 모든 기존 러닝 LLM 백필은 비용 증가 | MVP는 기존 데이터 embedding만 백필, LLM은 신규 러닝 중심 |
| 데이터 부족 | 유사 기록이 3개 미만일 수 있음 | threshold 완화, 기록 부족 전용 메시지 |
| 유사도 품질 | 텍스트 embedding만으로 운동 유사성을 충분히 반영하지 못할 수 있음 | 수치 벡터와 PostGIS score를 함께 사용 |
| 개인정보 | 경로와 건강 관련 정보가 LLM으로 전달됨 | 서버 호출만 허용, 최소 요약 데이터만 전달, 원본 좌표는 bbox/centroid 위주로 축약 |
| 의료 표현 | AI가 부상/건강 진단처럼 표현할 수 있음 | system prompt 금지 규칙, UI copy 검토 |

## Open Questions

- `gpt-5.4-mini`가 OpenAI API에서 실제 사용 가능한 정확한 model id인가?
- AI 리포트 생성 중 화면에서 기다리는 UX와 timeout/retry 기준은 어떻게 잡을지?
- Supabase 프로젝트의 Postgres/pgvector 버전에서 HNSW index를 사용할 수 있는가?
- 기존 러닝 백필은 운영 프로젝트에서 언제 실행할 것인가?
- 사용자에게 원본 위치 기반 비교를 LLM에 전달한다는 고지를 어디에 표시할 것인가?
- 유사 러닝 검색 범위는 같은 사용자만으로 제한할지, 익명화된 전체 사용자 패턴까지 확장할지?

## Feasibility And Feedback

### Fit With Existing Architecture

기존 구조는 Flutter가 `services/` 계층으로 Edge Function을 호출하고, 서버에서 DB 쓰기와 파생 처리를 담당한다. AI 리포트도 같은 패턴으로 붙일 수 있어 구조 궁합은 좋다. `create-run` 저장 후 파생 데이터를 만드는 흐름이 이미 있으므로, AI 생성은 별도 Edge Function과 테이블로 분리하는 방식이 가장 자연스럽다.

### Implementation Difficulty

난이도는 중상이다. Flutter UI 자체보다 DB migration, pgvector/PostGIS 혼합 scoring, Edge Function timeout, LLM JSON 안정화, 기존 데이터 백필이 핵심 리스크다.

### User Value

사용자는 단순 기록 대신 "이번 러닝이 과거의 어떤 러닝과 비슷했고 무엇이 나아졌는지"를 바로 볼 수 있다. 졸업작품 목표였던 지속 동기와 개인화 분석에도 잘 맞는다.

### MVP Recommendation

첫 개발 batch는 DB/RPC와 feature extraction까지로 제한한다. 두 번째 batch에서 LLM 리포트 생성과 조회 API를 붙이고, 세 번째 batch에서 Flutter 결과/분석 화면을 연결한다. 이렇게 나누면 러닝 저장 안정성을 유지하면서 AI 기능을 점진적으로 검증할 수 있다.

### Not For MVP

기존 모든 러닝에 대한 LLM 리포트 생성, 타 사용자 데이터 기반 비교, 장기 훈련 계획 자동 생성은 MVP 이후로 미룬다.

## References

- Supabase Docs: Generate Embeddings, built-in Edge Function AI inference with `gte-small`
- Supabase Docs: Semantic Search with pgvector and Edge Functions
- OpenAI Docs: Models list, implementation 전에 `gpt-5.4-mini` availability 확인 필요
