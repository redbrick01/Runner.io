# `android/`

## 역할

`android/`는 Flutter Android runner와 러닝 중 백그라운드/잠금화면 제어를 위한 Kotlin 네이티브 코드를 포함합니다. 모바일 실제 사용 환경에서 앱이 항상 전면에 있지 않아도 러닝 상태를 유지하고 알림 action으로 제어할 수 있도록 보조합니다.

## 주요 파일

| 파일 | 설명 |
|---|---|
| `app/src/main/AndroidManifest.xml` | 위치, 백그라운드 위치, foreground service, notification, wake lock 권한 선언, Google Maps API key placeholder, service/receiver 등록 |
| `app/src/main/kotlin/com/example/runner_flutter/MainActivity.kt` | Flutter MethodChannel `com.example.runner_flutter/live_activity` 처리, 알림 권한 요청, foreground service 시작/갱신/종료 |
| `app/src/main/kotlin/com/example/runner_flutter/RunLockScreenService.kt` | 러닝 중 foreground service, 위치 추적, 알림 표시, pause/resume/stop/cancel action 처리 |
| `app/src/main/kotlin/com/example/runner_flutter/RunActionReceiver.kt` | 알림 action을 service와 Flutter pending action으로 전달 |
| `gradle/`, `settings.gradle.kts`, `gradlew` | Android Gradle 빌드 구성 |

## 동작 흐름

```text
Flutter RunningMapPage
-> MethodChannel 호출
-> MainActivity
-> RunLockScreenService 시작/갱신
-> Android notification action
-> RunActionReceiver
-> service 또는 Flutter pending action으로 전달
```

## 관련 기능

- Android Google Maps API key 주입
- 백그라운드 위치 추적 보조
- 러닝 중 foreground notification
- 잠금화면/알림에서 일시정지, 재개, 종료, 취소 action 처리

## 검증

```bash
./gradlew :app:compileDebugKotlin
flutter run
```

## 참고 사항

- `android/local.properties`에 `GOOGLE_MAPS_API_KEY=...`를 설정하며 이 파일은 Git에 커밋하지 않습니다.
- 백그라운드 위치, 알림 권한, 배터리 최적화 정책은 실제 Android 기기에서 확인하는 것이 안전합니다.
- `.gradle/`, `.kotlin/`, `local.properties`, build output은 Git 관리 대상이 아닙니다.
