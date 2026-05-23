# `ios/` iOS 네이티브 구조

Flutter iOS runner와 Live Activity, HealthKit workout session 연동 코드가 들어 있다.

## 핵심 파일

- `Runner/AppDelegate.swift`
  - `Info.plist`의 `GoogleMapsAPIKey` 값을 읽어 Google Maps를 초기화
  - `RunLiveActivityPlugin` 등록
- `Runner/SceneDelegate.swift`
  - Flutter scene lifecycle 연결
- `Runner/RunLiveActivityPlugin.swift`
  - Flutter MethodChannel `com.example.runner_flutter/live_activity` 처리
- `Runner/RunLiveActivityManager.swift`
  - ActivityKit Live Activity 시작/갱신/종료
  - HealthKit workout session 시작/중지 보조
- `Runner/RunLiveActivityShared.swift`
  - Live Activity action payload 저장/소비
- `Runner/RunWidgetExtension/`
  - 잠금화면/Dynamic Island용 Live Activity UI
  - pause/resume/stop/cancel intent
- `Runner/Info.plist`
  - 위치 권한 문구, HealthKit 권한 문구, background mode, Live Activity 설정

## 검증

```bash
flutter run -d ios
```

Live Activity와 HealthKit은 시뮬레이터보다 실제 기기에서 검증하는 것이 안전하다. 위치 권한은 `Always` 승격 흐름까지 확인한다.

## Google Maps API Key

`Info.plist`에는 `$(GOOGLE_MAPS_API_KEY)` placeholder만 커밋한다. 실제 키는 Xcode build setting 또는 Git에 올리지 않는 로컬 xcconfig에서 설정한다.

```xcconfig
GOOGLE_MAPS_API_KEY = your-ios-restricted-key
```

## Git 제외 대상

`Pods/`, `.symlinks/`, `Flutter/ephemeral/`, `xcuserdata/`, `UserInterfaceState.xcuserstate`는 `.gitignore`로 제외한다.
