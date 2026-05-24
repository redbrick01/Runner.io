# Supabase 보안 Advisor 오류 수정 보고서

작성일: 2026-05-24
대상 프로젝트: `runner_flutter`
관련 화면/기능: Supabase DB/RPC/RLS, Edge Functions

## 1. 이슈 요약

- 원격 Supabase lint에서 `public.apply_territory_points()`가 존재하지 않는 `profiles.updated_at` 컬럼을 참조하는 오류가 확인되었다.
- Supabase advisor에서 app-owned public 테이블 RLS 비활성화, mutable `search_path`, 공개 실행 가능한 `SECURITY DEFINER` RPC, 중복 인덱스가 확인되었다.
- 영향 범위는 러닝 포인트/영토 유지 포인트 처리, public table 직접 접근 보안, Edge Function 기반 지도/프로필 조회 API이다.
- 심각도는 높음이다. DB maintenance RPC 오류와 RLS 비활성화는 원격 데이터/API 보안에 직접 영향을 줄 수 있다.

## 2. 재현 절차

1. 연결된 Supabase 프로젝트 `ifqrceunenzqusppfxgi`에서 DB lint를 실행한다.
2. `supabase db lint --linked` 결과를 확인한다.
3. `public.apply_territory_points()` 오류와 PostGIS 확장 함수 lint 결과를 구분한다.
4. `supabase db advisors --linked --output json`으로 security/performance advisor 결과를 확인한다.

## 3. 기대 동작

- app-owned RPC는 존재하는 컬럼만 참조해야 한다.
- public schema에 노출된 앱 테이블은 RLS가 켜져 있어야 한다.
- 내부 maintenance용 `SECURITY DEFINER` 함수는 `anon`/`authenticated`가 직접 실행할 수 없어야 한다.
- Edge Functions는 RLS 적용 후에도 필요한 데이터만 정상 응답해야 한다.

## 4. 실제 동작

- `public.apply_territory_points()`가 `profiles.updated_at`, `profiles.next_process_at`을 업데이트하려고 했다.
- 실제 `profiles` 테이블에는 `updated_at`, `next_process_at` 컬럼이 없다.
- `profiles`, `runs`, `territories`, `point_history`, `user_point_daily`, `run_ai_features`, `run_splits`, `run_ai_reports` 등 app-owned 테이블에 RLS가 꺼져 있었다.
- `apply_territory_points`, `apply_territory_worker`, `run_apply_territory_points_with_lock`, `set_run_ai_feature_geometry` 등이 공개 실행 가능하다는 advisor 경고가 있었다.

## 5. 영향 범위

| 영역 | 영향 |
|---|---|
| 사용자 화면 | 영토 GeoJSON, 프로필/랭킹 API가 RLS 변경 후 영향을 받을 수 있음 |
| 데이터/API | 영토 유지 포인트 RPC, public table 접근 권한, RPC execute 권한 |
| 저장/동기화 | 러닝 저장 trigger/service role 흐름은 유지해야 함 |
| 네이티브/권한 | 영향 없음 |
| 테스트/빌드 | Supabase CLI lint/advisor, Edge Function 정적 검증 필요 |

## 6. 관련 코드 및 데이터 흐름

관련 파일:

- `supabase/migrations/20260524070000_fix_supabase_security_advisors.sql`
- `supabase/migrations/20260524071500_tighten_rls_and_rpc_permissions.sql`
- `supabase/functions/user-ranking/index.ts`
- `supabase/functions/territory-geojson/index.ts`

데이터 흐름:

```text
Flutter service
-> Supabase Edge Function
-> service role DB client 또는 인증 확인 client
-> RPC/table query
-> JSON 응답
```

## 7. 원인 분석

### 7.1 원인 후보 1: 오래된 no-arg territory RPC

- 가능성: 초기 schema dump에 남은 `apply_territory_points()` 오버로드가 현재 `profiles` 스키마와 불일치했다.
- 근거: `profiles` 실제 컬럼 조회 결과 `updated_at`, `next_process_at`이 없었다.
- 확인 방법: `information_schema.columns` 조회와 DB lint 결과 비교.

### 7.2 원인 후보 2: 공개 schema 기본 권한과 RLS 미설정

- 가능성: 초기 원격 schema dump의 `GRANT ALL`과 RLS 미설정 상태가 유지되었다.
- 근거: advisor가 app-owned public table RLS disabled와 `SECURITY DEFINER` 공개 실행 경고를 보고했다.
- 확인 방법: advisor JSON 집계와 `pg_tables.rowsecurity` 확인.

## 8. 최종 원인

- 직접 원인은 현재 테이블 구조와 맞지 않는 legacy no-arg `apply_territory_points()` 정의이다.
- 보안 경고의 원인은 app-owned public 테이블에 RLS가 켜져 있지 않았고, 내부 RPC execute 권한이 `PUBLIC` 또는 `anon`/`authenticated`에 열려 있었기 때문이다.
- 기존 테스트는 Edge Function/service role 경로 중심이라 public table 직접 접근 정책과 DB advisor 항목을 검증하지 못했다.

## 9. 수정 내용

| 파일 | 수정 내용 | 의도 |
|---|---|---|
| `supabase/migrations/20260524070000_fix_supabase_security_advisors.sql` | no-arg `apply_territory_points()`를 worker 호출로 재정의, app-owned 테이블 RLS 활성화, owner-scoped policy 추가, function `search_path` 고정, duplicate constraint 제거 | 실제 DB 오류 제거와 기본 보안 강화 |
| `supabase/migrations/20260524071500_tighten_rls_and_rpc_permissions.sql` | RLS policy의 `auth.uid()` 호출을 `(SELECT auth.uid())`로 보정, internal SECURITY DEFINER 함수의 `PUBLIC` execute 회수 | advisor follow-up 경고 감소 |
| `supabase/functions/user-ranking/index.ts` | 인증은 anon client로 확인하고, profile/rank RPC는 service role client로 호출 | RLS 이후에도 전역 rank 계산 유지 |
| `supabase/functions/territory-geojson/index.ts` | GeoJSON RPC 호출을 service role client로 변경 | RLS 이후에도 공개 지도 응답 유지, 반환 필드는 함수에서 제한 |

## 10. 검증 결과

### 10.1 자동 테스트

```bash
deno fmt --check supabase/functions/user-ranking/index.ts supabase/functions/territory-geojson/index.ts
deno check supabase/functions/user-ranking/index.ts supabase/functions/territory-geojson/index.ts
supabase db push --linked --dry-run
supabase db push --linked --yes
supabase db lint --linked
supabase migration list --linked
```

결과:

- `deno fmt --check`: 통과
- `deno check`: 통과
- `supabase db push --linked --dry-run`: 적용 대상 migration 확인
- `supabase db push --linked --yes`: `20260524070000`, `20260524071500` 적용 완료
- `supabase db lint --linked`: app-owned `apply_territory_points` 오류 제거 확인
- `supabase migration list --linked`: 두 migration이 원격 이력에 반영됨

최종 lint 잔여:

- `public.st_findextent`
- `public.populate_geometry_columns`
- `public.postgis_full_version`
- `public.lockrow`
- `public.addauth`

위 항목은 PostGIS/long transaction 확장 함수 영역으로, 앱 소유 RPC가 아니다.

### 10.2 수동 테스트

| 테스트 | 절차 | 기대 결과 | 실제 결과 | 성공 여부 |
|---|---|---|---|---|
| Territory GeoJSON 공개 호출 | `territory-geojson?limit=1` HTTPS 호출 | 200 JSON 응답 | `FeatureCollection` 응답 | 성공 |
| Edge Function 배포 확인 | `supabase functions list --project-ref ifqrceunenzqusppfxgi` | 수정 대상 함수 version 갱신 | `user-ranking` v11, `territory-geojson` v7 | 성공 |

### 10.3 회귀 테스트

- `territory-geojson`은 `--no-verify-jwt`로 재배포해 로그인 전 지도 표시 흐름을 유지했다.
- `user-ranking`은 사용자 토큰 검증 후 service role RPC를 호출하도록 바꿔 전역 rank 계산이 RLS로 축소되지 않게 했다.

## 11. 남은 확인 사항

- 최종 `supabase db advisors --linked --output json`은 후속 migration 이후 Supabase pooler의 temporary CLI role 인증 차단(`ECIRCUITBREAKER`)으로 완료하지 못했다.
- `spatial_ref_sys` RLS disabled와 `postgis` extension in public은 PostGIS 확장 관리 영역이다. migration role이 `spatial_ref_sys` 소유자가 아니어서 RLS를 켤 수 없었다.
- Auth leaked password protection은 DB migration이 아니라 Supabase Auth 설정에서 별도 활성화해야 한다.
- 실제 로그인 사용자 토큰 기반 `user-ranking` 호출은 별도 테스트 계정/앱 세션으로 추가 확인하는 것이 좋다.

## 12. 재발 방지

- Supabase DB/RPC 변경 후 `supabase db lint --linked`와 `supabase db advisors --linked`를 함께 실행한다.
- 새 app-owned public 테이블을 만들 때 migration 안에서 RLS와 최소 policy를 같이 추가한다.
- 내부 maintenance RPC는 `SECURITY DEFINER`가 필요하더라도 `PUBLIC`, `anon`, `authenticated` execute 권한을 열지 않는다.
- RLS 적용 후 전역 집계가 필요한 API는 Edge Function service role 경유로 제한된 응답만 반환한다.

## 13. 결론

- app-owned DB 오류와 주요 RLS/권한 경고는 migration과 Edge Function 배포로 수정했다.
- PostGIS 확장 영역과 Auth 설정 항목은 안전한 앱 코드 migration 범위를 벗어나 남은 확인 사항으로 분리했다.
- 최종 advisor 재조회는 Supabase pooler 임시 인증 차단이 풀린 뒤 재실행해야 한다.
