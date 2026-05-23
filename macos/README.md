# `macos/`

## 역할

`macos/`는 Flutter macOS desktop target을 위한 네이티브 runner 프로젝트입니다. 현재 저장소의 핵심 기능은 모바일 러닝 앱에 집중되어 있으며, macOS 폴더는 Flutter 멀티플랫폼 프로젝트 구조의 일부로 유지됩니다.

## 주요 파일

| 파일/폴더 | 설명 |
|---|---|
| `Runner/` | macOS 앱 runner, entitlements, Info.plist, 앱 아이콘 |
| `Flutter/` | Flutter macOS 빌드 설정과 plugin registrant |
| `RunnerTests/` | 기본 macOS runner test |
| `Podfile`, `Podfile.lock` | macOS CocoaPods 의존성 관리 파일 |

## 동작 흐름

```text
flutter run -d macos
-> macOS Runner 실행
-> Flutter 엔진이 Dart 앱 로드
```

## 관련 기능

- Flutter desktop 실행 대상
- macOS 앱 패키징 기반 구조

## 참고 사항

- 위치 추적, Google Maps, 모바일 백그라운드 제어는 macOS에서 모바일과 동일하게 검증되지 않았습니다.
- `Pods/`, `.symlinks/`, `Flutter/ephemeral/`, `xcuserdata/` 같은 생성 파일은 Git 관리 대상이 아닙니다.
