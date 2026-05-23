# `linux/`

## 역할

`linux/`는 Flutter Linux desktop target을 위한 runner 프로젝트입니다. 현재 Runner.io의 주요 구현과 검증은 모바일 앱, Supabase 백엔드, Android/iOS 네이티브 보조 기능에 집중되어 있습니다.

## 주요 파일

| 파일/폴더 | 설명 |
|---|---|
| `CMakeLists.txt` | Linux runner 빌드 설정 |
| `runner/` | Linux 앱 runner C++ 코드 |
| `flutter/` | Flutter Linux plugin registrant 및 빌드 설정 |

## 동작 흐름

```text
flutter run -d linux
-> CMake 기반 Linux runner 빌드
-> Flutter 엔진이 Dart 앱 로드
```

## 관련 기능

- Flutter desktop 실행 대상
- Linux 빌드 구조 유지

## 참고 사항

- 모바일 위치 권한, Android foreground service, iOS Live Activity는 Linux target에서 제공되지 않습니다.
- Linux target 지원 여부는 실제 실행 환경에서 별도 확인이 필요합니다.
