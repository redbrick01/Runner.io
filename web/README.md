# `web/`

## 역할

`web/`은 Flutter Web 빌드 대상의 shell 파일과 PWA 관련 메타데이터를 포함합니다. 현재 프로젝트의 주요 시연 대상은 모바일 앱이지만, Flutter가 생성한 Web target 구성이 함께 유지되어 있습니다.

## 주요 파일

| 파일 | 설명 |
|---|---|
| `index.html` | Flutter Web 앱이 로드되는 HTML 진입점 |
| `manifest.json` | Web/PWA 앱 이름, 아이콘, 표시 방식 등 메타데이터 |
| `favicon.png` | 브라우저 favicon |
| `icons/` | Web manifest에서 사용하는 앱 아이콘 리소스 |

## 동작 흐름

```text
flutter build web
-> web/index.html shell 사용
-> Flutter Web bundle 로드
-> manifest/icon 메타데이터 적용
```

## 관련 기능

- Flutter Web 실행 및 빌드
- Web/PWA 메타데이터 제공
- 브라우저 아이콘 표시

## 참고 사항

- Google Maps, 위치 권한, 백그라운드 러닝 기능은 모바일 환경과 Web 환경에서 동작 조건이 다릅니다.
- 졸업작품의 Android/iOS 네이티브 기능은 `web/`에서 제공되지 않습니다.
- Web 배포를 목표로 할 경우 Maps API key의 Web 도메인 제한을 별도로 설정해야 합니다.
