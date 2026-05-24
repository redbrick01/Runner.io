# `supabase/functions/`

## 역할

`supabase/functions/`는 Supabase Edge Functions 기반 API 계층입니다. Flutter 앱의 `lib/services/` 계층에서 HTTP로 호출하며, 인증 확인, 요청 검증, DB 저장/조회, 랭킹 집계, 프로필 수정 같은 서버 측 처리를 담당합니다.

## 주요 파일

| 함수 | Method | 설명 |
|---|---|---|
| `create-run/index.ts` | `POST` | 완료된 러닝 기록과 split을 저장하고 DB trigger를 통해 포인트/영토 처리를 유도 |
| `run-history/index.ts` | `GET` | 현재 로그인 사용자의 러닝 기록과 split 목록 조회 |
| `generate-run-ai-report/index.ts` | `POST` | 특정 러닝의 embedding 생성, 유사 러닝 검색, 서버 LLM 기반 AI 리포트 저장 |
| `run-ai-report/index.ts` | `GET` | 특정 러닝 또는 최신 AI 러닝 분석 리포트 조회 |
| `backfill-run-embeddings/index.ts` | `POST` | 기존 러닝 데이터의 Supabase 내장 embedding 백필 |
| `point-history/index.ts` | `GET` | 기간 조건에 맞는 포인트 변동 이력 조회 |
| `profile-leaderboard/index.ts` | `GET` | 일/주/월/년/전체 기준 랭킹 및 내 주변 순위 조회 |
| `user-ranking/index.ts` | `GET` | 현재 사용자 프로필, 총점, 순위 요약 조회 |
| `update-profile/index.ts` | `POST` | 닉네임, 색상, 키, 몸무게, 비밀번호 수정 |
| `territory-geojson/index.ts` | `GET` | 지도 bbox 기준 영토 GeoJSON 조회 |
| `run-history/README.md` | 문서 | `run-history` 함수 요청/응답 예시 |

## 동작 흐름

```text
Flutter 화면
-> lib/services/*
-> SupabaseApi.getFunctionJson/postFunctionJson
-> Edge Function
-> Supabase Auth token 검증
-> service role client 또는 auth client로 DB 접근
-> JSON 응답 반환
```

러닝 저장 흐름은 다음과 같습니다.

```text
create-run
-> Authorization token으로 사용자 확인
-> 요청 body 필수 필드 검증
-> 필요 시 프로필 weight_kg로 calories 보정
-> runs insert
-> run_splits insert
-> DB trigger/RPC에서 포인트와 영토 갱신
```

AI 분석은 러닝 저장 중 자동으로 실행하지 않는다. 사용자가 러닝 리포트 화면에서 AI 분석 버튼을 누르면 `generate-run-ai-report`가 호출되고, Supabase 내장 `gte-small` embedding 생성, `match_similar_runs` RPC 유사 러닝 검색, 서버 LLM(`gpt-5.4-mini` 기본값) 리포트 저장이 진행된다.

## 관련 기능

- 러닝 기록 저장과 조회
- 러닝 저장 후 AI 비교 분석 리포트 생성/조회
- 기존 러닝 embedding 백필
- 포인트 이력 조회
- 랭킹 집계
- 프로필 조회와 수정
- 지도용 영토 데이터 조회

## 참고 사항

- 인증이 필요한 함수는 `Authorization: Bearer <access_token>`을 확인합니다.
- `SUPABASE_SERVICE_ROLE_KEY`는 Edge Function 내부에서만 사용해야 합니다.
- 날짜/기간 랭킹은 KST 기준 로직을 사용합니다.
- 함수 경로는 kebab-case입니다. 보고서에 `update_profile`로 표기된 항목은 실제 코드에서는 `update-profile`입니다.

## 배포 예시

```bash
supabase functions deploy create-run
supabase functions deploy run-history
supabase functions deploy generate-run-ai-report
supabase functions deploy run-ai-report
supabase functions deploy backfill-run-embeddings
supabase functions deploy point-history
supabase functions deploy profile-leaderboard
supabase functions deploy user-ranking
supabase functions deploy update-profile
supabase functions deploy territory-geojson
```
