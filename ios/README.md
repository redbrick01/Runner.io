# `ios/`

## 역할

`ios/`는 Flutter iOS runner와 러닝 상태를 잠금화면/Dynamic Island에 표시하기 위한 Live Activity 및 Widget Extension 코드를 포함합니다. iOS 환경에서 앱을 열지 않아도 러닝 진행 상태를 확인할 수 있도록 보조합니다.

## 주요 파일

| 파일/폴더 | 설명 |
|---|---|
| `Runner/AppDelegate.swift` | `Info.plist`의 `GoogleMapsAPIKey`를 읽어 Google Maps 초기화, `RunLiveActivityPlugin` 등록 |
| `Runner/SceneDelegate.swift` | Flutter scene lifecycle 연결 |
| `Runner/RunLiveActivityPlugin.swift` | Flutter MethodChannel `com.example.runner_flutter/live_activity` 처리 |
| `Runner/RunLiveActivityManager.swift` | ActivityKit Live Activity 시작/갱신/종료, HealthKit workout session 보조 |
| `Runner/RunLiveActivityShared.swift` | Live Activity action payload 저장/소비 |
| `Runner/RunWidgetExtension/` | 잠금화면/Dynamic Island UI, pause/resume/stop/cancel intent |
| `Runner/Info.plist` | 위치 권한 문구, HealthKit 권한 문구, background mode, Live Activity 설정 |

## 동작 흐름

```text
Flutter RunningMapPage
-> MethodChannel 호출
-> RunLiveActivityPlugin
-> RunLiveActivityManager
-> ActivityKit Live Activity 갱신
-> RunWidgetExtension에서 잠금화면/Dynamic Island 표시
```

## 관련 기능

- iOS Google Maps 초기화
- Live Activity 기반 러닝 상태 표시
- Dynamic Island 표시
- HealthKit workout session 보조
- 잠금화면 action intent 처리

## 검증

```bash
flutter run -d ios
```

## 로컬 설정

iOS Google Maps API key는 Git에 커밋하지 않는 로컬 파일에 둔다.

```xcconfig
// ios/Flutter/Local.xcconfig
GOOGLE_MAPS_API_KEY = your-ios-restricted-key
```

`Debug.xcconfig`와 `Release.xcconfig`는 `Local.xcconfig`를 선택적으로 include한다. 이 파일이 없으면 `Info.plist`의 `$(GOOGLE_MAPS_API_KEY)` placeholder가 치환되지 않아, 지도 화면 진입 시 Google Maps SDK 초기화 예외가 발생할 수 있다.

## 참고 사항

- Live Activity와 HealthKit은 시뮬레이터보다 실제 기기에서 검증하는 것이 안전합니다.
- `Info.plist`에는 `$(GOOGLE_MAPS_API_KEY)` placeholder를 사용하며 실제 키는 Xcode build setting 또는 `ios/Flutter/Local.xcconfig`에 둡니다.
- `Pods/`, `.symlinks/`, `Flutter/ephemeral/`, `xcuserdata/`, `UserInterfaceState.xcuserstate`는 Git 관리 대상이 아닙니다.
