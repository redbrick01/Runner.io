# `supabase/`

## 역할

`supabase/`는 Runner.io의 백엔드 구성을 담고 있습니다. Supabase 로컬 개발 설정, PostgreSQL/PostGIS migration, Deno 기반 Edge Functions, seed 진입점으로 구성됩니다.

## 주요 파일

| 경로 | 설명 |
|---|---|
| `config.toml` | Supabase CLI 로컬 개발 설정 |
| `seed.sql` | 로컬 DB reset 후 실행되는 seed 진입점 |
| `migrations/` | 테이블, PostGIS 함수, trigger, RPC 정의 |
| `functions/` | Flutter 앱이 호출하는 Supabase Edge Functions |

## 동작 흐름

```text
Flutter App
-> Supabase Auth로 사용자 인증
-> Edge Function 호출
-> PostgreSQL/PostGIS 읽기/쓰기
-> trigger/RPC로 포인트/영토 파생 처리
-> JSON 응답 반환
```

러닝 저장 후 서버 내부 흐름:

```text
create-run
-> runs insert
-> run_splits insert
-> process_run_geometry trigger
-> territories 갱신
-> handle_run_points trigger
-> point_history, profiles, user_point_daily 갱신
```

## 관련 기능

- 사용자 인증과 프로필 데이터
- 러닝 기록 저장 및 조회
- split 단위 분석 데이터
- 포인트 이력 및 일별 집계
- 기간별 랭킹
- PostGIS 기반 영토 점령/병합/차감
- 지도 표시용 GeoJSON 제공

## 로컬 실행

```bash
supabase start
supabase db reset
supabase functions serve
```

Edge Function은 다음 환경 변수를 기대합니다.

```text
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
```

## 참고 사항

- `SUPABASE_SERVICE_ROLE_KEY`는 서버 측 함수에서만 사용해야 하며 클라이언트 앱, README 예시, 공개 Git 저장소에 넣지 않습니다.
- PostGIS geometry 연산은 입력 경로 품질에 민감합니다. 앱의 위치 필터링과 DB의 geometry 보정 로직을 함께 고려해야 합니다.
- 원격 프로젝트에 migration을 적용하기 전에는 백업과 테스트 프로젝트 검증이 필요합니다.
- 랭킹은 `profiles.total_points`, `user_point_daily`, `point_history`를 함께 사용하므로 기간 집계 의미가 어긋나지 않게 관리해야 합니다.

