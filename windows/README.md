# `windows/`

## 역할

`windows/`는 Flutter Windows desktop target을 위한 runner 프로젝트입니다. 현재 프로젝트의 핵심 시연 기능은 모바일 러닝 앱에 맞춰져 있으며, Windows 폴더는 Flutter 멀티플랫폼 구조의 일부로 포함되어 있습니다.

## 주요 파일

| 파일/폴더 | 설명 |
|---|---|
| `CMakeLists.txt` | Windows runner 빌드 설정 |
| `runner/` | Windows 앱 runner C++ 코드, 리소스, manifest |
| `flutter/` | Flutter Windows plugin registrant 및 빌드 설정 |

## 동작 흐름

```text
flutter run -d windows
-> CMake 기반 Windows runner 빌드
-> Flutter 엔진이 Dart 앱 로드
```

## 관련 기능

- Flutter desktop 실행 대상
- Windows 앱 패키징 기반 구조

## 참고 사항

- Android/iOS 백그라운드 러닝 보조 기능은 Windows target에서 제공되지 않습니다.
- GPS, Google Maps, 위치 권한 동작은 모바일과 다를 수 있어 별도 검증이 필요합니다.
