# AI Similarity Live Voice Coaching Implementation Report 20260528

## Summary

1km 페이스 알림에 과거 유사 split 기반 AI 코칭을 후속 음성으로 붙이는 MVP를 구현했다. 기존 페이스 알림은 지연 없이 즉시 재생하고, AI 코칭은 현재 구간 snapshot을 Supabase Edge Function으로 보내 과거 유사 구간과 비교한 뒤 허용 시간 안에만 후속 TTS로 재생한다.

이번 구현은 로컬 코드 구현, 정적/단위 검증, Supabase 원격 DB migration 적용, Edge Function 배포까지 완료한 상태다. 실제 기기 러닝 QA와 segment embedding backfill 실행은 후속 작업으로 남아 있다.

## Implemented Stages

- 실시간 음성 코칭 계획서 작성과 피드백 반영
- split 단위 AI feature 저장 테이블과 유사 구간 검색 RPC 추가
- 기존 embedding backfill 함수에 segment backfill 모드 추가
- 라이브 러닝 코칭 Edge Function 추가
- Flutter 라이브 코칭 service/model 추가
- 1km split TTS 흐름에 AI 후속 코칭 연결
- AI 페이스 코치 ON/OFF 로컬 설정과 마이페이지 토글 추가
- 서비스 파싱과 설정 저장 단위 테스트 추가
- 관련 README 문서 갱신
- Supabase 원격 DB migration 적용
- 관련 Edge Function 배포

## Changed Files

- `docs/new_features/ai_running_similarity_analysis/live_voice_coaching_plan.md`
- `docs/new_features/ai_running_similarity_analysis/live_voice_coaching_implementation_report_20260528.md`
- `docs/README.md`
- `supabase/migrations/20260528090000_add_live_run_segment_ai_coaching.sql`
- `supabase/functions/_shared/run-ai.ts`
- `supabase/functions/generate-live-run-coaching/index.ts`
- `supabase/functions/backfill-run-embeddings/index.ts`
- `supabase/functions/README.md`
- `lib/services/live_run_coaching_service.dart`
- `lib/services/live_run_coaching_settings.dart`
- `lib/services/README.md`
- `lib/main/running_map_page.dart`
- `lib/main/my_page.dart`
- `test/live_run_coaching_service_test.dart`
- `pubspec.yaml`
- `pubspec.lock`

## Product Behavior

기존 1km 페이스 알림은 그대로 유지한다.

```text
N킬로미터, 구간 페이스 M분 SS초
```

AI 페이스 코치가 켜져 있고 앱이 Flutter foreground 경로에서 split을 감지하면, 페이스 알림을 먼저 재생한 뒤 라이브 코칭 요청을 보낸다. 응답이 허용 window 안에 도착하면 짧은 코칭 문장을 후속으로 재생한다.

```text
3킬로미터, 구간 페이스 5분 48초.
비슷한 기록보다 안정적이에요. 지금 리듬을 이어가세요.
```

지연 정책:

- 페이스 알림은 AI 요청과 무관하게 즉시 재생
- AI 텍스트 생성 timeout은 Flutter service 기준 8초
- AI 음성 시작 허용 window는 split 감지 후 12초
- 12초를 넘거나 다음 km 알림과 겹칠 가능성이 있으면 해당 AI 코칭 폐기
- foreground가 아니거나 native-only background split 감지 경로에서는 기존 페이스 TTS만 유지

## Data Layer Changes

### `run_segment_ai_features`

신규 테이블을 추가했다.

역할:

- 저장된 `run_splits`를 split 단위 AI feature로 변환해 저장
- Supabase built-in `gte-small` embedding 저장
- 현재 구간과 유사한 과거 split 검색의 후보 데이터 제공
- 다음 split outcome을 저장해 "이 구간 이후 유지/하락/회복" 패턴을 코칭 근거로 사용

주요 컬럼:

- `user_id`, `run_id`, `split_index`
- `embedding vector(384)`
- `feature_json`, `summary_text`
- `split_pace_s_per_km`
- `avg_pace_until_split_s_per_km`
- `pace_delta_prev_s`, `pace_delta_avg_s`
- `next_split_pace_s_per_km`, `next_pace_delta_s`, `next_outcome`
- `embedding_status`, `error_message`, `embedded_at`

보안:

- RLS 활성화
- authenticated 사용자는 자기 row SELECT만 가능
- insert/update/backfill/search는 Edge Function service role 중심으로 수행

### `match_similar_run_segments`

신규 RPC를 추가했다.

입력:

```text
p_user_id uuid
p_split_index integer
p_embedding vector(384)
p_feature_json jsonb
p_exclude_run_id bigint default null
p_limit integer default 5
```

검색 조건:

- 같은 사용자만 검색
- `p_exclude_run_id`가 있으면 해당 run 제외
- 현재 km 기준 인접 split index 우선
- embedding completed row만 검색
- 같은 run에서 과도하게 많이 뽑히지 않도록 run별 rank 제한

점수:

```text
total_score =
  embedding_score * 0.60 +
  split_index_score * 0.20 +
  numeric_score * 0.20
```

numeric score는 split pace, 누적 평균 pace, 이전 split 대비 변화, 평균 대비 변화, 상승량 차이를 사용한다. `exp()` 입력은 `least(..., 60)`으로 clamp해 underflow 위험을 줄였다.

## Edge Function Changes

### `_shared/run-ai.ts`

추가된 주요 유틸:

- `buildSegmentFeatures`: 저장된 run summary와 splits에서 segment feature 목록 생성
- `upsertSegmentFeature`: segment embedding row upsert
- `buildLiveSegmentSnapshot`: Flutter live split payload 정규화
- `buildFallbackLiveCoaching`: 데이터 부족/LLM 실패 시 규칙 기반 코칭 생성
- `callOpenAiLiveCoaching`: 현재 split과 유사 split outcome을 OpenAI Responses API에 전달하고 짧은 JSON 코칭 응답 파싱

### `generate-live-run-coaching`

신규 Edge Function을 추가했다.

처리 흐름:

```text
Authorization 확인
-> live split payload 정규화
-> 현재 구간 summary text 생성
-> gte-small embedding 생성
-> match_similar_run_segments RPC 호출
-> 유사 split 3개 미만이면 fallback 코칭 반환
-> 유사 split 3개 이상이면 OpenAI live coaching 호출
-> LLM 실패 시 fallback 코칭 반환
```

응답 예시:

```json
{
  "status": "completed",
  "coaching_message": "비슷한 기록보다 안정적이에요. 지금 리듬을 이어가세요.",
  "coaching_category": "steady",
  "similar_segment_count": 4,
  "fallback_used": false
}
```

### `backfill-run-embeddings`

기존 run embedding backfill 동작을 유지하면서 `target=segments` query parameter를 추가했다.

예시:

```text
POST /functions/v1/backfill-run-embeddings?target=segments&limit=20
```

`target=segments`일 때는 각 run의 split을 `run_segment_ai_features`로 변환하고 segment별 embedding을 생성한다. 기존 `target` 기본값은 `runs`라 기존 호출 호환성은 유지된다.

## Flutter Changes

### `LiveRunCoachingService`

신규 service/model을 추가했다.

- `LiveRunCoachingRequest`: 현재 split snapshot 직렬화
- `LiveRunCoachingResponse`: status, coaching message, category, similar segment count, fallback 여부 파싱
- `generateCoaching`: `generate-live-run-coaching` 호출, 8초 timeout 적용

### `LiveRunCoachingSettings`

`SharedPreferences` 기반 로컬 설정을 추가했다.

- 기본값: enabled
- key: `live_run_ai_coach_enabled`
- 마이페이지 토글과 러닝 지도 화면에서 공유

### `RunningMapPage`

기존 `_announceSplitIfNeeded()` 흐름에 live coaching을 optional 후속 단계로 연결했다.

동작:

1. 1km 도달 감지
2. 구간 페이스 문장 생성
3. 기존 TTS 경로로 페이스 알림 즉시 재생
4. foreground이고 AI 코치 설정이 켜져 있으면 live coaching 요청
5. 8초 안에 응답이 오고, split 감지 후 12초 안에 음성 시작 가능하면 후속 TTS 재생
6. 실패/지연/paused/background/current token mismatch면 폐기

추가 상태:

- `_lastAnnouncedSplitAscentMeters`
- `_pauseCount`
- `_liveCoachingRequestToken`
- `_liveSplitPaceHistory`
- `_recentLiveCoachingCategories`
- `_aiPaceCoachEnabled`

native-only background split TTS 경로는 건드리지 않았다. Android background invoke와 iOS native split tracking 경로에서는 기존 페이스 알림만 유지된다.

### `MyPage`

마이페이지에 `AI 페이스 코치` 토글을 추가했다. 사용자는 러닝 전 AI 후속 코칭을 켜고 끌 수 있다.

## Tests Added Or Updated

신규 테스트:

- `test/live_run_coaching_service_test.dart`

검증 내용:

- `LiveRunCoachingRequest` payload serialization
- `LiveRunCoachingResponse` parsing
- `LiveRunCoachingSettings` default enabled와 persisted disabled 값

기존 테스트 확인:

- `test/run_ai_report_service_test.dart`

## Verification Results

로컬 검증 결과:

- `flutter pub get`: passed after sandbox escalation for Flutter SDK cache write
- `dart format ...`: passed after sandbox escalation for Flutter SDK cache write
- `deno fmt supabase/functions/_shared/run-ai.ts supabase/functions/backfill-run-embeddings/index.ts supabase/functions/generate-live-run-coaching/index.ts`: passed
- `flutter analyze lib/main/running_map_page.dart`: passed
- `flutter analyze lib/main/my_page.dart lib/services/live_run_coaching_service.dart lib/services/live_run_coaching_settings.dart`: passed
- `deno check supabase/functions/generate-live-run-coaching/index.ts supabase/functions/backfill-run-embeddings/index.ts`: passed
- `flutter test test/live_run_coaching_service_test.dart`: passed, 3 tests
- `flutter test test/run_ai_report_service_test.dart`: passed, 2 tests
- `flutter analyze`: passed
- `deno check supabase/functions/generate-run-ai-report/index.ts supabase/functions/generate-live-run-coaching/index.ts supabase/functions/backfill-run-embeddings/index.ts`: passed

참고:

- `flutter test test/run_ai_report_service_test.dart` 실행 중 `build/unit_test_assets` cleanup 경고가 한 번 출력됐지만 테스트는 통과했다.
- Supabase 원격 migration과 Edge Function 배포는 완료했다.
- 실제 기기 QA는 아직 수행하지 않았다.

## Deployment Results

원격 Supabase 프로젝트 `Runner.io`에 적용했다.

적용된 migration:

```text
20260528090000_add_live_run_segment_ai_coaching.sql
```

배포된 Edge Functions:

```text
generate-live-run-coaching
backfill-run-embeddings
generate-run-ai-report
```

`generate-run-ai-report`는 `_shared/run-ai.ts` 변경 사항을 원격 번들과 맞추기 위해 함께 재배포했다.

검증:

- `supabase migration list --linked`: local/remote `20260528090000` 일치 확인
- `supabase functions list --output json`: `generate-live-run-coaching`, `backfill-run-embeddings`, `generate-run-ai-report` ACTIVE 확인

## Segment Backfill Results

기존 `run_splits` 기준 segment embedding 백필을 원격 Supabase 프로젝트에 실행했다.

```text
target=segments
scope=all
```

최종 검증 쿼리 결과:

```text
runs: 54
runs_with_splits: 35
split_rows: 140
segment_feature_runs: 35
segment_feature_rows: 140
embedding_status=completed: 140
```

운영 중 확인한 보정 사항:

- `limit=20` 배치는 Edge Function `WORKER_RESOURCE_LIMIT`에 걸릴 수 있어 `limit=1~3` 소배치로 재시도했다.
- 최초 후보 조회가 `runs` 기준이라 split이 없는 run을 반복 후보로 잡는 문제가 있어, `run_splits` 기준 후보 조회로 수정했다.
- 부분 처리된 run을 완료로 오인하지 않도록, completed segment row 수가 split row 수 이상인 run만 후보에서 제외하도록 수정했다.
- 백필을 위해 일시적으로 `backfill-run-embeddings`를 `--no-verify-jwt`로 배포하고 `BACKFILL_ADMIN_SECRET` 헤더를 사용했다.
- 백필 완료 후 `backfill-run-embeddings`를 다시 기본 배포하여 `verify_jwt=true` 상태를 확인했다.

## Remaining Runtime Steps

1. 실제 기기 QA

- AI 페이스 코치 ON 상태에서 1km split 도달
- 페이스 알림 즉시 재생 확인
- AI 코칭 후속 재생 확인
- AI 코치 OFF 상태에서 API 미호출/기존 페이스 알림만 재생 확인
- 네트워크 불안정 또는 LLM 실패 시 fallback/폐기 확인
- native-only background/잠금화면 경로에서 기존 split TTS 회귀 확인

## Known Limitations

- 실제 러닝 중 OpenAI 응답 지연 분포는 아직 측정하지 않았다.
- AI 음성 코칭은 Flutter foreground 또는 Flutter-backed 경로에서만 동작한다.
- native-only Android/iOS 백그라운드 split 감지 경로는 기존 페이스 TTS만 유지한다.
- AI 코치 설정은 로컬 `SharedPreferences`에 저장되며 기기 간 동기화되지 않는다.
- 현재 MVP는 목표 페이스 UI를 제공하지 않는다. `goal_pace_seconds` 필드는 서버/클라이언트 contract에만 준비되어 있다.
- 현재 원격 프로젝트의 기존 split segment embedding은 완료됐지만, 이후 생성되는 신규 run은 저장/분석 플로우에서 segment feature 생성이 이어져야 한다.

## Follow-Up Items

- Supabase 테스트 프로젝트에 migration 적용 후 `match_similar_run_segments` 샘플 쿼리 검증
- `generate-live-run-coaching` 배포 후 실제 payload smoke test
- 실제 기기에서 1km split TTS와 AI 후속 TTS timing 측정
- AI 코칭 음성 시작 window를 10~15초 범위에서 실측 기반 조정
- native-only background에서 AI 코칭을 지원할지 별도 설계
- 목표 페이스 설정 UI와 request contract 연결
