# `lib/login/`

## 역할

`lib/login/`은 사용자가 Runner.io에 진입하기 전 필요한 인증 화면을 담당합니다. Supabase Auth 기반 이메일/비밀번호 인증을 사용하며, 로그인 성공 후 메인 러닝 지도 화면으로 이동하는 시작 흐름을 구성합니다.

## 주요 파일

| 파일 | 설명 |
|---|---|
| `login_page.dart` | 이메일/비밀번호 입력, `AuthService.signIn` 호출, 로그인 성공 시 `RunningMapPage`로 이동 |
| `signup_page.dart` | 이메일/비밀번호 회원가입 입력, `AuthService.signUp` 호출, 가입 성공 후 로그인 화면 복귀 |

## 동작 흐름

```text
앱 실행
-> main.dart에서 Supabase 세션 확인
-> 세션 없음
-> LoginPage 표시
-> 로그인 또는 회원가입
-> Supabase Auth 처리
-> 로그인 성공 시 RunningMapPage 진입
```

`login_page.dart`와 `signup_page.dart`는 인증 처리 세부 구현을 직접 갖기보다 `lib/services/auth_service.dart`를 통해 Supabase Auth를 호출합니다. 화면은 사용자 입력, 오류 표시, 화면 이동에 집중합니다.

## 관련 기능

- 이메일/비밀번호 로그인
- 이메일/비밀번호 회원가입
- 로그인 성공 후 러닝 지도 화면 진입
- 앱 시작 시 세션이 없는 사용자의 기본 진입점

## 참고 사항

- 인증 상태의 최종 기준은 Supabase 세션입니다.
- 로그인 성공 후 이동 대상은 현재 코드 기준 `RunningMapPage`입니다.
- 인증 로직을 바꿀 때는 `AuthService`, `main.dart`의 세션 분기, 로그인/회원가입 widget test를 함께 확인해야 합니다.
