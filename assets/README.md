# `assets/`

## 역할

`assets/`는 앱에서 사용하는 정적 리소스의 원본을 보관합니다. 현재는 앱 아이콘 생성에 사용하는 원본 이미지가 중심입니다.

## 주요 파일

| 파일 | 설명 |
|---|---|
| `app_icon/app_icon_ios_1024.png` | iOS 앱 아이콘 생성에 사용하는 1024px 원본 이미지 |

## 동작 흐름

```text
assets/app_icon/app_icon_ios_1024.png
-> tools/generate_app_icon.swift
-> 플랫폼별 앱 아이콘 리소스 생성
-> android/ios/macos 등 플랫폼 프로젝트에 반영
```

## 관련 기능

- 앱 아이콘 리소스 관리
- 플랫폼별 아이콘 생성 작업의 원본 관리

## 참고 사항

- 현재 `pubspec.yaml`의 Flutter asset 등록 항목은 별도로 정의되어 있지 않습니다.
- 앱 화면에서 사용하는 이미지 asset을 추가할 경우 `pubspec.yaml` 등록 여부를 함께 확인해야 합니다.
- 원본 아이콘을 교체하면 플랫폼별 생성 아이콘도 함께 갱신해야 합니다.

