# `supabase/migrations/`

## 역할

`supabase/migrations/`는 Runner.io 백엔드 데이터베이스의 schema, trigger, RPC, PostGIS 공간 처리 로직을 정의합니다. 러닝 기록 저장 이후 포인트, 일별 집계, 영토 생성/병합/차감 같은 핵심 서버 측 처리가 이 migration에 포함되어 있습니다.

## 주요 파일

| 파일 | 설명 |
|---|---|
| `20260523142500_initial_remote_schema.sql` | 원격 Supabase schema를 기준으로 정리된 초기 migration. 테이블, PostGIS 함수, trigger, RPC 포함 |
| `20260524000500_track_run_points_in_user_point_daily.sql` | 러닝 생성 시 `user_point_daily`의 `run_points`, `total_points`를 KST 기준으로 누적하도록 보강 |

## 동작 흐름

```text
create-run Edge Function
-> runs insert
-> run_splits insert
-> process_run_geometry trigger
-> geometry 정리 및 loop/area 계산
-> territories 생성/병합/차감
-> handle_run_points trigger
-> point_history 기록
-> profiles.total_points 갱신
-> user_point_daily upsert
```

## 관련 기능

- 러닝 기록 저장
- 러닝 경로 geometry 처리
- 영토 점령, 병합, 겹침 영역 차감
- 러닝 포인트 및 영토 유지 포인트 기록
- 전체/기간 랭킹 계산을 위한 누적 데이터 제공
- 지도 bbox 기준 영토 GeoJSON 조회

## 참고 사항

- PostGIS 함수는 입력 GPS 경로 품질에 민감합니다. 앱의 GPS 필터링과 DB의 geometry 보정 로직을 함께 고려해야 합니다.
- `user_point_daily`는 KST 기준 집계를 사용합니다.
- Supabase migration을 원격 프로젝트에 적용하기 전에는 백업과 테스트 프로젝트 검증이 필요합니다.
- 영토 유지 포인트는 `next_process_at` 기준 worker 함수와 연결되어 있으므로 배치 주기 변경 시 관련 함수 전체를 확인해야 합니다.
