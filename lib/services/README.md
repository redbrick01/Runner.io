# `lib/services/`

## 역할

`lib/services/`는 Flutter 화면과 Supabase Auth/Edge Functions 사이의 통신을 분리하는 서비스 계층입니다. 화면 파일이 HTTP header, 인증 token, JSON decode, API URL 구성 같은 세부사항을 직접 다루지 않도록 기능별 클래스로 나누어져 있습니다.

## 주요 파일

| 파일 | 설명 |
|---|---|
| `supabase_api.dart` | Supabase URL, anon key, Edge Function URL 생성, 공통 header, GET/POST JSON 처리, API 예외 처리 |
| `auth_service.dart` | Supabase Auth 로그인, 회원가입, 로그아웃 |
| `run_service.dart` | `create-run` Edge Function 호출 |
| `run_history_service.dart` | `run-history` 호출 및 `RunHistoryEntry` 변환 |
| `point_history_service.dart` | `point-history` 호출 |
| `ranking_service.dart` | `profile-leaderboard` 호출, top/context 랭킹 결과 정리 |
| `profile_service.dart` | `user-ranking`, `profile-leaderboard`, `update-profile` 호출 |
| `territory_service.dart` | `territory-geojson` 호출 |
| `running_map_service.dart` | 지도 화면에서 필요한 프로필/영토 조회 조합 |
| `user_profile_store.dart` | 프로필 snapshot 캐시와 화면 간 로컬 상태 동기화 |

## 동작 흐름

```text
화면 Widget
-> 기능별 Service
-> SupabaseApi 공통 GET/POST 처리
-> Supabase Edge Function
-> JSON 응답
-> Service에서 화면이 쓰기 쉬운 형태로 변환
```

`SupabaseApi.waitForSession()`은 인증이 필요한 API 호출 전에 현재 세션을 확인합니다. 공통 header에는 `apikey`와 필요한 경우 `Authorization: Bearer <access_token>`이 포함됩니다.

## 관련 기능

- 인증
- 러닝 저장
- 러닝 기록 조회
- 포인트 이력 조회
- 기간별 랭킹 조회
- 사용자 프로필 조회/수정
- 지도용 영토 GeoJSON 조회

## 참고 사항

- 현재 Supabase URL과 anon key가 코드 상수로 들어 있습니다. anon key는 공개 클라이언트 키 성격이 있지만, 공개 저장소에서는 RLS/도메인 제한/키 관리 정책을 반드시 확인해야 합니다.
- API 응답 스키마가 바뀌면 서비스 변환 로직과 화면 null/error 처리를 함께 점검해야 합니다.
- 서비스 계층 단위 테스트 확대는 보고서에서 향후 개선 과제로 언급되어 있습니다.
