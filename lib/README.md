# `lib/`

## 역할

`lib/`는 Flutter 클라이언트의 핵심 Dart 소스 폴더입니다. 앱 부팅, 테마, 인증 화면, 러닝 지도/결과/기록 화면, 러닝 계산 엔진, Supabase API 서비스 계층을 포함합니다.

## 주요 파일

| 파일/폴더 | 설명 |
|---|---|
| `main.dart` | Flutter binding 초기화, Supabase 초기화, 세션 기반 첫 화면 분기 |
| `app_colors.dart` | 앱 전체에서 사용하는 색상 토큰 |
| `login/` | 로그인/회원가입 화면 |
| `main/` | 러닝 지도, 결과, 기록, 포인트, 랭킹, 프로필 화면과 러닝 엔진 |
| `services/` | Supabase Auth 및 Edge Function 호출 계층 |

## 동작 흐름

```text
main.dart
-> Supabase.initialize
-> currentSession 확인
-> LoginPage 또는 RunningMapPage
-> 화면에서 services 호출
-> Supabase Auth/Edge Functions
-> 응답을 화면 상태에 반영
```

러닝 중에는 다음 흐름이 중심입니다.

```text
RunningMapPage
-> Geolocator 위치 stream
-> RunSessionEngine 계산
-> RunService.createRun
-> RunResultPage
```

## 관련 기능

- 앱 초기화와 테마
- 이메일/비밀번호 인증
- 지도 기반 러닝 기록
- 결과 리포트와 split 분석
- 러닝 기록, 포인트 이력, 랭킹
- 프로필 조회/수정
- Android/iOS 네이티브 백그라운드 기능과의 MethodChannel 연동

## 참고 사항

- 화면 코드는 `lib/main/`, 서버 통신은 `lib/services/`, 인증 화면은 `lib/login/`에 분리되어 있습니다.
- 러닝 계산 로직은 `run_session_engine.dart`에 집중되어 있어 단위 테스트 대상입니다.
- Edge Function 응답 스키마 변경 시 `services/`와 관련 화면을 함께 확인해야 합니다.
- `main.dart`와 `supabase_api.dart`에는 Supabase URL/anon key가 상수로 설정되어 있습니다. 공개 저장소 운영 시 키 제한과 RLS 정책을 확인해야 합니다.
