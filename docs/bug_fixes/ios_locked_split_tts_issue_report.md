# iOS 화면 잠금 중 페이스 TTS 미출력 이슈 수정 계획서

작성일: 2026-05-28
대상 플랫폼: iOS only
상태: 원인 재분석 완료, 구현 전 계획 수립

점검일: 2026-05-28
점검 결과: 계획 방향은 유지하되, split 판단 주체, 중복 안내 방지, 상태 동기화 기준을 보강한다.

## 1. 이슈 요약

iOS에서 러닝 중 앱 화면이 켜져 있고 메인 화면이 보이는 상태에서는 킬로미터당 페이스 음성 안내가 정상 출력된다.

하지만 러닝 세션이 유지되는 중 화면을 잠그고 꺼진 상태에서는 페이스 음성 안내가 출력되지 않는다.

이번 문서는 바로 구현하지 않고, 현재 코드 기준으로 확인된 원인과 수정 방향을 고정하기 위한 계획서다.

## 2. 확인된 증상

1. 러닝 중 세션은 유지된다.
2. 앱 화면이 켜져 있고 메인 화면이 보이면 페이스 음성 안내가 나온다.
3. 화면을 잠그고 꺼진 상태에서는 페이스 음성 안내가 나오지 않는다.
4. 따라서 단순히 TTS 문장 생성이나 foreground TTS 설정이 완전히 깨진 문제는 아니다.

## 3. 현재 구현 구조

### 3.1 Foreground 경로

관련 파일:

- `lib/main/running_map_page.dart`
- `lib/services/run_native_adapter.dart`

현재 foreground에서는 다음 흐름으로 음성 안내가 동작한다.

```text
Geolocator 위치 스트림 수신
-> RunSessionEngine 거리 누적
-> 1km split 도달 판단
-> _announceSplitIfNeeded()
-> flutter_tts speak()
```

이 경로는 앱이 active 상태일 때 정상 동작한다.

### 3.2 iOS background 보조 경로

관련 파일:

- `ios/Runner/RunLiveActivityPlugin.swift`
- `ios/Runner/RunLiveActivityManager.swift`
- `ios/Runner/Info.plist`

iOS 네이티브에는 다음 기능이 이미 일부 구현되어 있다.

- `CLLocationManager` 기반 위치 추적
- `AVSpeechSynthesizer` 기반 네이티브 음성 안내
- `AVAudioSession.playback` 설정
- 앱이 active가 아닐 때 `maybeAnnounceSplit()`에서 split 안내 시도
- `announceSplitInBackground` MethodChannel 처리

즉 "잠금 상태에서 iOS 네이티브가 대신 말한다"는 코드 자체는 존재한다.

## 4. 현재 구현의 핵심 문제

현재 문제는 "음성 합성 코드가 아예 없음"이 아니다.

문제는 iOS 잠금 상태에서 페이스 안내를 책임져야 하는 네이티브 경로가 러닝 시작 시 독립적이고 확실한 핵심 경로로 보장되지 않는다는 점이다.

현재 구조는 다음에 가깝다.

```text
러닝 시작
-> Flutter 위치 추적 시작
-> Live Activity 시작 요청
-> Live Activity 시작 성공
-> configureSplitTracking()
-> iOS 네이티브 위치 추적 시작
-> 잠금 상태 위치 업데이트 수신
-> 네이티브 split 판단
-> AVSpeechSynthesizer 음성 안내
```

이 구조에서는 아래 조건 중 하나만 실패해도 잠금 상태 음성 안내가 멈출 수 있다.

- Live Activity 시작 실패
- Always 위치 권한 미확보
- iOS 잠금 상태에서 네이티브 `CLLocationManager` 업데이트 미수신
- 네이티브 split 거리 누적이 Flutter 세션 거리와 어긋남
- 네이티브 speech 호출 실패가 로그/상태로 드러나지 않음

## 5. 원인 판단

가장 유력한 원인은 다음이다.

```text
Foreground에서는 Flutter가 split을 감지하고 직접 말해서 정상 동작한다.
Lock 상태에서는 iOS 네이티브가 split을 감지하고 말해야 하는데,
그 경로가 Live Activity 성공 이후의 보조 기능처럼 연결되어 있어 안정적으로 동작하지 않는다.
```

따라서 이 이슈는 단순 TTS 설정 문제가 아니라, 잠금 상태에서 "말해야 할 타이밍"을 잡는 주체가 불안정한 문제로 본다.

## 6. 수정 목표

수정의 목표는 다음과 같다.

1. iOS 잠금 상태에서는 Flutter TTS에 의존하지 않는다.
2. iOS 네이티브 러닝 split 추적을 Live Activity 성공 여부와 분리한다.
3. 러닝 시작 시 iOS 네이티브 split tracking을 명시적으로 시작한다.
4. 러닝 일시정지, 재개, 종료, 취소 시 네이티브 split tracking 상태를 명시적으로 동기화한다.
5. 실패 지점을 로그와 상태로 확인할 수 있게 만든다.
6. foreground 안내와 background 안내가 중복으로 나오지 않게 한다.

## 7. 수정 계획

### 7.0 설계 원칙 보강

수정 전 반드시 split 안내의 주체를 명확히 나눈다.

```text
앱 foreground:
  Flutter 세션 거리 기준으로 split 판단
  flutter_tts 또는 기존 foreground TTS 경로로 안내

앱 background / lock:
  iOS native CLLocationManager 거리 기준으로 split 판단
  AVSpeechSynthesizer로 안내
```

중요한 점은 background/lock 상태에서 Dart가 계속 살아 있을 수도 있다는 것이다. 이때 Flutter 위치 스트림과 iOS native 위치 스트림이 동시에 1km 도달을 감지하면 중복 안내가 발생할 수 있다.

따라서 iOS background/lock 상태에서는 Dart의 `_announceSplitIfNeeded()`가 안내의 primary trigger가 되지 않도록 정리한다. 필요하다면 Dart는 native 상태 동기화만 수행하고, 실제 음성 안내는 native가 담당한다.

### 7.1 iOS 네이티브 split tracking 전용 MethodChannel 추가

`RunLiveActivityPlugin.swift`에 Live Activity와 분리된 전용 메서드를 추가한다.

예상 메서드:

- `startIosSplitTracking`
- `updateIosSplitTracking`
- `stopIosSplitTracking`
- `getIosSplitTrackingStatus`

역할:

- `startIosSplitTracking`: 러닝 시작 직후 네이티브 위치 추적과 음성 세션 준비
- `updateIosSplitTracking`: Flutter 세션의 거리, 시간, pause 상태를 네이티브에 동기화
- `stopIosSplitTracking`: 러닝 종료/취소 시 위치 추적과 오디오 세션 정리
- `getIosSplitTrackingStatus`: 디버깅용 상태 확인

Live Activity는 잠금화면 표시용으로 유지하되, 페이스 안내의 필수 선행 조건으로 두지 않는다.

권장 payload:

```text
runId
elapsedSeconds
distanceMeters
isPaused
lastAnnouncedSplitKm
lastAnnouncedSplitElapsedSeconds
appLifecycleState
```

`startIosSplitTracking`은 `startLiveActivity` 성공 여부와 무관하게 호출되어야 한다. `startLiveActivity`가 실패해도 native split tracking은 계속 시작되어야 한다.

### 7.2 Flutter 러닝 시작/상태 변경 흐름에 iOS 전용 호출 연결

`running_map_page.dart`에서 iOS일 때 다음 시점에 네이티브 split tracking을 호출한다.

- 러닝 시작 직후
- 1초 timer 또는 위치 sample accept 시점의 상태 동기화
- 일시정지
- 재개
- 종료
- 취소
- foreground 복귀 시 native 상태 조회 후 Dart split 상태 동기화

중요 원칙:

```text
Android 기존 foreground service 흐름은 건드리지 않는다.
iOS Live Activity UI 흐름은 유지한다.
iOS split TTS 안정화만 별도 경로로 분리한다.
```

호출 순서 주의:

```text
_session.beginRun(...)
-> currentRunId 확보
-> startIosSplitTracking(...)
-> startLiveActivity(...)
```

이 순서가 중요한 이유는 native split tracking이 `runId`를 기준으로 상태를 유지하기 때문이다. Live Activity는 실패할 수 있으므로 split tracking보다 뒤에 둔다.

### 7.3 iOS 권한 상태를 명확히 확인

iOS 잠금 중 위치 업데이트를 위해 실제 기기에서 Always 권한이 필요하다.

수정 시 확인할 상태:

- location service enabled
- authorization status
- `allowsBackgroundLocationUpdates`
- `UIBackgroundModes`의 `location`, `audio`
- `AVAudioSession` 활성화 성공 여부

권한이 부족할 경우 조용히 실패하지 않고 로그에 명확히 남긴다.

### 7.4 네이티브 split 거리 기준 정리

현재 네이티브는 자체 `CLLocationManager` 위치 업데이트로 거리를 누적한다.

수정 방향:

- Flutter 세션 거리와 네이티브 거리 중 어떤 값을 split 기준으로 삼을지 명확히 정한다.
- 잠금 상태에서는 네이티브 위치 업데이트가 주 기준이 되어야 한다.
- 앱이 foreground로 복귀하면 Flutter 세션 값과 네이티브 상태를 동기화한다.
- 중복 안내 방지를 위해 `lastAnnouncedSplitKm`를 양쪽에서 동기화한다.

추가 기준:

- foreground에서 Flutter가 split 안내를 완료한 경우 native의 `lastAnnouncedSplitKm`도 같은 값으로 갱신한다.
- background에서 native가 split 안내를 완료한 경우 foreground 복귀 시 Dart의 `_lastAnnouncedSplitKm`를 native 값으로 갱신한다.
- 단순 거리 동기화만으로 `lastAnnouncedSplitKm`를 올리면 안 된다. 실제 음성 안내가 나가지 않았는데 안내 완료로 표시될 수 있기 때문이다.
- `updateIosSplitTracking`에서 Flutter 거리 값이 native 거리보다 크더라도, 앱이 background이면 그 거리 차이만으로 split 안내를 건너뛰지 않도록 처리한다.

권장 상태 모델:

```text
trackingDistanceMeters:
  현재 native가 알고 있는 누적 거리

lastAnnouncedSplitKm:
  실제 음성 안내까지 완료했거나, foreground에서 Dart 안내 완료가 확인된 split

lastSyncedFlutterDistanceMeters:
  Flutter에서 마지막으로 전달받은 거리. 보정 참고용이며 안내 완료 기준은 아님
```

### 7.5 디버깅 로그 추가

실기기에서 반드시 확인해야 하므로 다음 로그를 추가한다.

- iOS split tracking start 호출 여부
- 위치 권한 상태
- `startUpdatingLocation()` 호출 여부
- `didUpdateLocations` 수신 여부
- 누적 거리 변화
- completed km 계산 결과
- `speakSplitAnnouncement()` 호출 여부
- `AVAudioSession.setCategory` / `setActive` 성공 여부
- speech finish/cancel 여부

로그 prefix는 검색하기 쉽게 통일한다.

예:

```text
[iOS Split TTS] start tracking ...
[iOS Split TTS] location update ...
[iOS Split TTS] announce split ...
[iOS Split TTS] audio session failed ...
```

로그는 release 빌드에서 과도하게 남지 않도록 `NSLog` 사용 범위와 메시지 양을 제한한다. 실기기 검증이 끝나면 상세 위치 로그는 줄이고, start/stop/error/announce 중심 로그만 남긴다.

### 7.6 HealthKit workout session 조건 점검

현재 `RunWorkoutSessionManager`는 `iOS 26.0` 이상에서만 실행되도록 되어 있다.

이 조건은 실제 배포 대상 iPhone 대부분에서 workout session 보조 유지 장치가 꺼지는 결과를 만들 수 있다. `HKWorkoutSession` 자체가 정말 iOS 26 이상만 필요한지 확인하고, 가능한 경우 지원 가능한 iOS 버전으로 availability 조건을 낮춘다.

다만 이번 이슈의 1차 해결은 HealthKit에 의존하지 않는다. HealthKit은 백그라운드 유지력을 높이는 보조 수단으로 취급하고, split 안내의 핵심 경로는 `CLLocationManager` + `AVSpeechSynthesizer`로 둔다.

### 7.7 권한 UX 점검

코드는 `requestAlwaysAuthorization()`을 호출할 수 있지만, iOS 권한 정책상 사용자가 항상 허용을 선택하지 않으면 잠금 상태 위치 업데이트가 제한될 수 있다.

따라서 구현 후 다음 중 하나를 정한다.

- 러닝 시작 전 Always 권한이 아니면 경고를 보여준다.
- 러닝 시작은 허용하되, 잠금 상태 페이스 안내가 제한될 수 있음을 안내한다.
- 설정 앱으로 이동할 수 있는 안내를 제공한다.

이 UX는 기능 안정화 후 추가할 수 있지만, 최소한 로그에는 반드시 남긴다.

### 7.8 Dart 구현 세부안

`lib/main/running_map_page.dart`에 iOS 전용 native split tracking helper를 추가한다.

추가할 field:

```dart
bool _iosSplitTrackingActive = false;
bool _iosSplitTrackingStatusSyncInFlight = false;
```

추가할 helper:

```dart
Map<String, dynamic> _iosSplitTrackingPayload({
  required String lifecycleState,
})

Future<void> _startIosSplitTracking()
Future<void> _updateIosSplitTracking({required String reason})
Future<void> _stopIosSplitTracking({required String reason})
Future<void> _syncIosSplitTrackingStatus()
bool get _shouldLetNativeHandleSplitAnnouncement
```

`_iosSplitTrackingPayload` 기본 payload:

```text
runId: _currentRunId
elapsedSeconds: _seconds
distanceMeters: _totalDistance
isPaused: _isPaused
lastAnnouncedSplitKm: _lastAnnouncedSplitKm
lastAnnouncedSplitElapsedSeconds: _lastAnnouncedSplitElapsedSeconds
lifecycleState: resumed | inactive | paused | detached
```

각 helper의 역할:

- `_startIosSplitTracking`: iOS이고 `_currentRunId`가 있을 때 `startIosSplitTracking` 호출. 성공하면 `_iosSplitTrackingActive = true`.
- `_updateIosSplitTracking`: iOS이고 `_iosSplitTrackingActive`일 때만 `updateIosSplitTracking` 호출. 실패해도 러닝 자체는 중단하지 않는다.
- `_stopIosSplitTracking`: iOS일 때 `stopIosSplitTracking` 호출. 성공/실패와 무관하게 local flag는 false로 정리한다.
- `_syncIosSplitTrackingStatus`: foreground 복귀 시 `getIosSplitTrackingStatus` 호출 후 native의 `lastAnnouncedSplitKm`가 Dart보다 크면 Dart 값을 올린다.
- `_shouldLetNativeHandleSplitAnnouncement`: iOS이고 앱이 foreground가 아니며 native split tracking이 active이면 true.

`_announceSplitIfNeeded()` 수정 방향:

```text
if (_shouldLetNativeHandleSplitAnnouncement) {
  await _updateIosSplitTracking(reason: 'dart_split_detected_background');
  return;
}
```

이렇게 해야 background에서 Dart가 우연히 split을 감지하더라도 직접 `announceSplitInBackground`를 호출해 native 안내와 중복되는 일을 줄일 수 있다.

foreground에서 Flutter TTS 안내가 성공한 뒤에는 native에 마지막 안내 km를 동기화한다.

```text
await _nativeAdapter.speakSplit(speech);
await _updateIosSplitTracking(reason: 'foreground_split_announced');
```

`_beginRunning()` 수정 위치:

```text
_session.beginRun(...)
-> _startIosSplitTracking()
-> _startLiveActivity()
```

`_resumeRunning()` 수정 위치:

```text
_session.resume(...)
-> _updateIosSplitTracking(reason: 'resume')
-> _updateLiveActivity()
```

`_togglePause()`에서 pause 처리 후:

```text
_session.pause()
-> _updateIosSplitTracking(reason: 'pause')
-> _updateLiveActivity()
```

`_stopRunning()`과 `_cancelRunning()`에서는 Live Activity 종료와 별개로 `stopIosSplitTracking`을 호출한다. 저장 실패로 러닝을 다시 pause 상태로 되돌리는 경우에는 stop하지 않고 pause 상태를 native에 동기화한다.

### 7.9 Swift 구현 세부안

`ios/Runner/RunLiveActivityPlugin.swift`에 MethodChannel case를 추가한다.

```swift
case "startIosSplitTracking":
    startIosSplitTracking(call: call, result: result)
case "updateIosSplitTracking":
    updateIosSplitTracking(call: call, result: result)
case "stopIosSplitTracking":
    stopIosSplitTracking(call: call, result: result)
case "getIosSplitTrackingStatus":
    getIosSplitTrackingStatus(result: result)
```

추가할 native field:

```swift
private var isSplitTrackingActive = false
private var lastSyncedFlutterDistanceMeters: Double = 0
private var lastNativeLocationUpdateAt: Date?
private var lastSplitAnnouncementAt: Date?
private var lastAudioSessionError: String?
private var lastLocationError: String?
```

기존 `configureSplitTracking`, `updateSplitTracking`, `stopSplitTracking`은 Live Activity 전용이 아니라 아래 역할로 재정리한다.

- `startIosSplitTracking`: 새 run이면 상태 초기화 후 `locationManager.startUpdatingLocation()`.
- `updateIosSplitTracking`: 같은 run이면 elapsed, pause, Flutter distance, foreground 안내 완료 상태만 동기화.
- `stopIosSplitTracking`: 위치 추적, speech, chime, audio session 정리.
- `getIosSplitTrackingStatus`: 현재 상태 map 반환.

`getIosSplitTrackingStatus` 반환값:

```text
runId
isTracking
isPaused
trackingDistanceMeters
lastSyncedFlutterDistanceMeters
lastAnnouncedSplitKm
lastAnnouncedSplitElapsedSeconds
lastNativeLocationUpdateAt
lastSplitAnnouncementAt
authorizationStatus
lastAudioSessionError
lastLocationError
```

`didUpdateLocations` 처리 기준:

1. `isSplitTrackingActive == true`인지 확인한다.
2. `trackingRunID != nil`인지 확인한다.
3. pause 상태면 거리 누적과 안내를 하지 않는다.
4. accuracy가 나쁜 위치는 버린다.
5. 첫 위치는 기준점으로만 저장한다.
6. 이동거리, 속도 필터를 통과한 경우에만 `trackingDistanceMeters`를 증가시킨다.
7. 앱이 active가 아닐 때만 `maybeAnnounceSplit()`을 호출한다.

`maybeAnnounceSplit()` 처리 기준:

```text
completedKm = floor(trackingDistanceMeters / 1000)
if completedKm <= lastAnnouncedSplitKm:
  return

splitDuration = effectiveElapsedSeconds - lastAnnouncedSplitElapsedSeconds
speech 생성
speakSplitAnnouncement(speech)
lastAnnouncedSplitKm = completedKm
lastAnnouncedSplitElapsedSeconds = effectiveElapsedSeconds
lastSplitAnnouncementAt = Date()
```

주의: speech 성공 callback을 기다려서 `lastAnnouncedSplitKm`를 올리면 다음 위치 업데이트에서 같은 split을 반복 호출할 수 있다. 따라서 "안내 시도 시작" 시점에 올리고, 실패는 `lastAudioSessionError`로 남긴다.

### 7.10 상태 전이표

| 상황 | Dart 처리 | iOS native 처리 |
|---|---|---|
| 러닝 시작 | `_session.beginRun` 후 `startIosSplitTracking` 호출 | 상태 초기화, background location 시작 |
| foreground 위치 갱신 | Flutter 거리/화면 갱신, foreground split 안내 | `updateIosSplitTracking`으로 상태만 동기화 |
| foreground split 안내 완료 | Dart `lastAnnouncedSplitKm` 갱신 | 같은 km를 native에 동기화 |
| 화면 잠금/inactive | Dart는 native 상태 동기화만 수행 | native가 위치 누적과 split 안내 담당 |
| background split 안내 완료 | 직접 처리 없음 | native `lastAnnouncedSplitKm` 갱신 |
| foreground 복귀 | `getIosSplitTrackingStatus`로 Dart 상태 보정 | 상태 반환 |
| 일시정지 | `_session.pause`, native update | 거리 누적 중지 |
| 재개 | countdown 후 `_session.resume`, native update | 거리 누적 재개 |
| 정상 종료 | 저장 흐름 진입, 성공 후 stop | 위치/audio 정리 |
| 저장 실패 | 러닝 pause 상태 유지, stop 금지 | pause 상태로 update |
| 취소 | stop 호출 | 위치/audio 정리 |

### 7.11 구현 제외 범위

이번 수정에서 제외할 항목:

- Android foreground service 수정
- UI 디자인 변경
- 러닝 저장 payload 구조 변경
- Supabase 저장 로직 변경
- Live Activity UI redesign
- 페이스 계산 공식 변경

단, 권한 부족 안내 UI는 실기기 로그 확인 후 필요하면 후속 작업으로 추가한다.

## 8. 구현 순서

1. `RunLiveActivityPlugin.swift`에 `startIosSplitTracking`, `updateIosSplitTracking`, `stopIosSplitTracking`, `getIosSplitTrackingStatus` case를 추가한다.
2. Swift payload parser를 만들고 invalid argument일 때 `FlutterError(code: "invalid_args", ...)`를 반환한다.
3. Swift 상태 field에 `isSplitTrackingActive`, `lastSyncedFlutterDistanceMeters`, `lastNativeLocationUpdateAt`, `lastSplitAnnouncementAt`, `lastAudioSessionError`, `lastLocationError`를 추가한다.
4. 기존 `configureSplitTracking`, `updateSplitTracking`, `stopSplitTracking`을 새 MethodChannel 메서드에서 재사용 가능한 내부 함수로 정리한다.
5. `startLiveActivity` 내부에서 split tracking을 시작하던 의존성을 제거하거나, 중복 start가 되지 않도록 idempotent하게 만든다.
6. `running_map_page.dart`에 `_iosSplitTrackingActive`, `_iosSplitTrackingStatusSyncInFlight` field를 추가한다.
7. Dart에 `_iosSplitTrackingPayload`, `_startIosSplitTracking`, `_updateIosSplitTracking`, `_stopIosSplitTracking`, `_syncIosSplitTrackingStatus`, `_shouldLetNativeHandleSplitAnnouncement` helper를 추가한다.
8. `_beginRunning()`에서 `_session.beginRun(...)` 이후 `startIosSplitTracking`, 그 다음 `startLiveActivity` 순서로 호출한다.
9. `_togglePause()`, `_resumeRunning()`, `_stopRunning()`, `_cancelRunning()`에 native update/stop 호출을 연결한다.
10. `_announceSplitIfNeeded()`에서 iOS background/lock 상태는 native primary trigger가 되도록 early return 경로를 추가한다.
11. foreground split TTS 성공 후 native에 `foreground_split_announced` reason으로 상태를 동기화한다.
12. `didChangeAppLifecycleState(resumed)`에서 `getIosSplitTrackingStatus`를 호출해 Dart의 마지막 안내 km를 보정한다.
13. HealthKit availability 조건을 검토하고, 필요하면 별도 보조 수정으로 분리한다.
14. 실기기 로그를 보고 실패 지점을 확정한다.
15. 로그 확인 후 필요하면 권한 안내 UI 또는 fallback 정책을 추가한다.

## 9. 검증 계획

### 9.1 정적 검증

- `flutter analyze lib/main/running_map_page.dart`
- iOS 빌드 또는 최소한 Swift 컴파일 확인

### 9.2 실기기 foreground 검증

1. iPhone에서 앱 실행
2. 러닝 시작
3. 화면이 켜진 상태로 1km 도달
4. 페이스 안내 출력 확인
5. 기존 foreground 동작이 깨지지 않았는지 확인

### 9.3 실기기 잠금 상태 검증

1. iPhone에서 러닝 시작
2. 화면 잠금
3. 다음 1km split 도달
4. 잠금 상태에서 페이스 안내 출력 확인
5. 로그에서 `didUpdateLocations`와 `announce split`이 찍혔는지 확인
6. 같은 split이 두 번 안내되지 않는지 확인
7. 앱 복귀 후 다음 split 번호가 건너뛰거나 반복되지 않는지 확인

### 9.4 권한별 검증

- 위치 권한이 "앱 사용 중"일 때
- 위치 권한이 "항상 허용"일 때
- 권한이 거부된 상태일 때

예상 기준:

- "항상 허용"이 아니면 잠금 상태 안내가 제한될 수 있다.
- 제한되는 경우 앱이 조용히 실패하지 않고 원인을 로그 또는 사용자 안내로 드러내야 한다.

### 9.5 오디오 상태 검증

- 무음 모드
- 기기 스피커
- Bluetooth 이어폰
- 다른 음악 앱 재생 중
- 잠금화면 상태

### 9.6 Live Activity 실패 격리 검증

1. Live Activity가 시작되지 않는 상황을 만든다.
2. 러닝을 시작한다.
3. `startIosSplitTracking`은 정상 시작되는지 확인한다.
4. 화면 잠금 상태에서 split 안내가 Live Activity 성공 여부와 무관하게 나오는지 확인한다.

### 9.7 중복 안내 회귀 검증

1. foreground에서 1km 안내를 듣는다.
2. 바로 화면을 잠근다.
3. 1km 안내가 다시 나오지 않는지 확인한다.
4. 2km 안내는 잠금 상태에서 한 번만 나오는지 확인한다.
5. 앱을 다시 켠 뒤 2km 안내가 반복되지 않는지 확인한다.

## 10. 완료 기준

이 이슈는 아래 조건을 만족할 때 완료로 본다.

1. iOS 실제 기기에서 화면 잠금 상태로 1km split 도달 시 페이스 음성 안내가 나온다.
2. foreground에서도 기존처럼 음성 안내가 나온다.
3. pause/resume 이후에도 다음 split 안내가 정상 동작한다.
4. 종료/취소 후 네이티브 위치 추적과 오디오 세션이 정리된다.
5. Live Activity 시작 실패가 페이스 음성 안내 실패로 이어지지 않는다.
6. 실패 시 원인을 로그로 확인할 수 있다.
7. foreground/background 전환 경계에서 같은 km 안내가 중복 출력되지 않는다.
8. background에서 나온 안내 상태가 foreground 복귀 후 Dart 상태에 반영된다.

## 11. 주의 사항

- 이 수정은 iOS 기준으로만 진행한다.
- Android foreground service 코드는 수정 대상이 아니다.
- 단순히 `flutter_tts` 설정을 다시 바꾸는 방식은 근본 해결로 보지 않는다.
- iOS 잠금 상태 동작은 시뮬레이터로 충분히 검증할 수 없으므로 실제 iPhone 테스트가 필수다.
- 위치 권한이 "항상 허용"이 아닌 경우 잠금 상태 동작은 iOS 정책상 제한될 수 있다.
- background에서 native가 primary trigger가 되면 Flutter 화면의 실시간 거리 표시와 native 누적 거리가 잠시 다를 수 있다. foreground 복귀 시 동기화 정책을 반드시 확인한다.
