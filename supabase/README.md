# `supabase/` 백엔드 구조

이 폴더는 Runner Flutter의 Supabase 로컬 설정, DB migration, Edge Function을 포함한다.

## 구성

```text
supabase/
  config.toml
  seed.sql
  migrations/
  functions/
```

- `config.toml`: Supabase CLI 로컬 개발 설정
- `seed.sql`: 로컬 DB reset 후 seed 데이터 진입점
- `migrations/`: PostgreSQL/PostGIS schema, trigger, RPC
- `functions/`: Deno 기반 Supabase Edge Functions

## 주요 테이블

| 테이블 | 설명 |
|---|---|
| `profiles` | 사용자 프로필, 색상, 총 포인트, 키/몸무게 |
| `runs` | 러닝 기록, 거리, 시간, 포인트, 경로 geometry, 면적 |
| `run_splits` | 러닝 split 단위 기록 |
| `territories` | 사용자별 영토 geometry와 면적, 기본 포인트 |
| `point_history` | 러닝/영토 포인트 이벤트 이력 |
| `user_point_daily` | KST 기준 일별 포인트 집계 |

## Edge Functions

| 경로 | 설명 |
|---|---|
| `functions/create-run` | 러닝 기록 생성, split 저장, 포인트/영토 trigger 유도 |
| `functions/run-history` | 현재 사용자의 러닝 기록과 split 조회 |
| `functions/point-history` | 기간별 포인트 이력 조회 |
| `functions/profile-leaderboard` | 기간별 랭킹 top/context 조회 |
| `functions/user-ranking` | 현재 사용자 프로필과 전체 순위 조회 |
| `functions/update-profile` | 프로필/비밀번호 수정 |
| `functions/territory-geojson` | 지도 bbox 기준 영토 GeoJSON 조회 |

## 로컬 실행

```bash
supabase start
supabase db reset
supabase functions serve
```

Edge Function은 다음 환경 변수를 기대한다.

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

`SUPABASE_SERVICE_ROLE_KEY`는 서버 측 함수에서만 사용해야 하며 클라이언트 앱, README 예시, 공개 Git 저장소에 넣지 않는다.

## 데이터 처리 흐름

```text
create-run
-> runs insert
-> run_splits insert
-> process_run_geometry trigger
-> upsert_or_merge_territory / subtract_territory_and_update
-> handle_run_points trigger
-> point_history insert
-> profiles.total_points update
-> user_point_daily upsert
```

## 운영 주의사항

- PostGIS geometry 연산은 입력 경로 품질에 민감하다. 앱에서 위치 정확도와 비정상 속도를 필터링하지만, 서버에서도 `clean_geom`, `geom_to_polygon` 계층으로 보정한다.
- 랭킹은 `profiles.total_points`, `user_point_daily`, `point_history`를 조합한다. 기간 랭킹 수정 시 세 테이블의 의미가 어긋나지 않게 확인한다.
- 영토 유지 포인트는 `next_process_at`와 worker 함수 기준으로 누적된다. 배치 주기 변경 시 `apply_territory_points`와 cron 설정을 함께 확인한다.

