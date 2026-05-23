# Supabase Edge Functions

각 함수는 Deno 기반 Supabase Edge Function이다. 클라이언트에서는 `lib/services/supabase_api.dart`를 통해 호출한다.

## 함수 목록

| 함수 | 주요 입력 | 주요 출력/효과 |
|---|---|---|
| `create-run` | `started_at`, `ended_at`, `duration`, `distance`, `point`, `path_geom`, `splits` | `runs` row 생성, split 저장, DB trigger로 포인트/영토 갱신 |
| `run-history` | `limit`, `offset` | 현재 사용자 러닝 기록과 split 목록 |
| `point-history` | `range_type`, `anchor_date`, `limit`, `offset` | 기간별 포인트 이력 |
| `profile-leaderboard` | `mode`, `range_type`, `anchor_date`, `user_id` | top 랭킹 또는 내 주변 랭킹 |
| `user-ranking` | 없음 | 현재 사용자 프로필/랭킹 요약 |
| `update-profile` | `nick_name`, `color_hex`, `height_cm`, `weight_kg`, `password` | 프로필 또는 비밀번호 수정 |
| `territory-geojson` | `bbox`, `srid`, `limit` | 지도 표시용 FeatureCollection |

## 공통 규칙

- 인증이 필요한 함수는 `Authorization: Bearer <access_token>`을 확인한다.
- `SUPABASE_SERVICE_ROLE_KEY`는 Edge Function 내부에서만 사용한다.
- CORS preflight 요청은 각 함수에서 처리한다.
- 날짜/랭킹 집계는 KST 기준을 사용한다.

## 배포 예시

```bash
supabase functions deploy create-run
supabase functions deploy run-history
supabase functions deploy point-history
supabase functions deploy profile-leaderboard
supabase functions deploy user-ranking
supabase functions deploy update-profile
supabase functions deploy territory-geojson
```

