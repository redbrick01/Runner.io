# `android/` Android 네이티브 구조

Flutter Android runner와 러닝 중 백그라운드/잠금화면 처리를 위한 Kotlin 코드가 들어 있다.

## 핵심 파일

- `app/src/main/AndroidManifest.xml`
  - 위치, 백그라운드 위치, foreground service, notification, wake lock 권한 선언
  - Google Maps API key meta-data는 `${GOOGLE_MAPS_API_KEY}` placeholder로 주입
  - `RunLockScreenService`, `RunActionReceiver` 등록
- `app/src/main/kotlin/com/example/runner_flutter/MainActivity.kt`
  - Flutter MethodChannel `com.example.runner_flutter/live_activity` 처리
  - 알림 권한 요청, foreground service 시작/갱신/종료, pending action 전달
- `RunLockScreenService.kt`
  - 러닝 중 foreground service
  - 위치 추적, 알림 표시, pause/resume/stop/cancel action 처리
- `RunActionReceiver.kt`
  - 알림 action을 service와 Flutter 쪽 pending action으로 전달

## 검증

```bash
./gradlew :app:compileDebugKotlin
flutter run
```

백그라운드 위치, 알림 권한, 배터리 최적화 설정은 에뮬레이터보다 실제 Android 기기에서 확인하는 것이 좋다.

## Google Maps API Key

`android/local.properties`에 다음 값을 추가한다. 이 파일은 Git에 커밋하지 않는다.

```properties
GOOGLE_MAPS_API_KEY=your-android-restricted-key
```

CI에서는 같은 이름의 환경변수 `GOOGLE_MAPS_API_KEY`를 설정한다.

## Git 제외 대상

`.gradle/`, `.kotlin/`, `local.properties`, app build output은 `.gitignore`로 제외한다.
