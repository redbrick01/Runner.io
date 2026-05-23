# iOS 화면 잠금 중 페이스 TTS 미출력 이슈 분석 보고서

## 1. 이슈 요약

iOS에서 러닝 중 앱 화면이 켜져 있을 때는 킬로미터당 페이스 TTS가 정상 출력되지만, 화면을 잠그고 러닝을 계속하면 1km 단위 페이스 안내가 출력되지 않는 문제가 보고되었다.

앱 코드를 확인한 결과, foreground 상태에서는 Flutter/Dart의 위치 스트림과 `flutter_tts`가 안내를 처리한다. 반면 화면 잠금 또는 백그라운드 상태에서는 iOS가 Dart 실행과 플러그인 오디오 출력을 제한할 수 있으므로 네이티브 `AVSpeechSynthesizer` 경로를 사용해야 한다.

## 2. 재현 절차

1. iOS 기기에서 러닝을 시작한다.
2. 화면이 켜진 상태에서 1km 도달 시 페이스 TTS가 출력되는지 확인한다.
3. 러닝을 계속한 상태로 화면을 잠근다.
4. 다음 1km 지점에 도달한다.
5. 페이스 TTS가 출력되지 않는지 확인한다.

## 3. 기대 동작 / 실제 동작

기대 동작:

- 화면 잠금 중에도 위치 추적이 유지된다.
- 거리 누적과 1km 도달 판단이 계속 동작한다.
- 1km, 2km, 3km 도달 시 구간 페이스 TTS가 출력된다.

실제 동작:

- 화면이 켜진 상태에서는 TTS가 정상 출력된다.
- 화면 잠금 상태에서는 킬로미터당 페이스 TTS가 출력되지 않는다.

## 4. 관련 코드 분석

### Flutter/Dart 안내 흐름

관련 파일:

- `lib/main/running_map_page.dart`
- `lib/main/run_session_engine.dart`

흐름:

1. `Geolocator.getPositionStream()`에서 GPS 위치를 수신한다.
2. `_session.addPositionSample()`이 유효 위치 샘플을 거리로 누적한다.
3. 위치 샘플이 accept되면 `_announceSplitIfNeeded()`가 호출된다.
4. `_totalDistance / 1000`의 floor 값으로 완료 km를 판단한다.
5. `_lastAnnouncedSplitKm`보다 큰 경우 구간 페이스 문장을 만든다.
6. foreground에서는 `flutter_tts`의 `_splitTts.speak()`로 출력한다.

문제 지점:

- 기존 코드에서 iOS 백그라운드/잠금 상태도 Dart `flutter_tts` 경로로 떨어질 수 있었다.
- iOS 화면 잠금 상태에서는 Dart timer/stream 실행과 Flutter plugin 기반 TTS 출력이 지연되거나 제한될 수 있다.

### iOS 네이티브 경로

관련 파일:

- `ios/Runner/RunLiveActivityPlugin.swift`
- `ios/Runner/Info.plist`

확인된 설정:

- `UIBackgroundModes`에 `location`, `audio`가 선언되어 있다.
- `NSLocationAlwaysAndWhenInUseUsageDescription`가 선언되어 있다.
- `RunLiveActivityPlugin`에는 `CLLocationManager` 기반 위치 추적과 `AVSpeechSynthesizer` 기반 음성 안내 코드가 이미 존재한다.
- `AVAudioSession`은 `.playback` category와 Bluetooth 옵션을 사용한다.

기존 한계:

- iOS 백그라운드 split 안내를 Dart에서 명시적으로 네이티브 `AVSpeechSynthesizer` 경로로 위임하는 MethodChannel 핸들러가 없었다.

## 5. 원인 후보

### 1. iOS 잠금 상태에서 `flutter_tts` 호출 제한

발생 가능성: 높음

근거:

- 화면이 켜진 상태에서는 `flutter_tts`가 정상 동작한다.
- 화면 잠금 상태에서는 iOS가 Flutter plugin 호출과 오디오 세션 활성화를 제한할 수 있다.
- 네이티브 `AVSpeechSynthesizer`와 `AVAudioSession.playback` 경로가 더 적합하다.

### 2. iOS 백그라운드 위치 권한 부족

발생 가능성: 중간

근거:

- `Info.plist`에는 Always 권한 문구와 background location mode가 존재한다.
- 하지만 실제 사용자가 위치 권한을 "항상 허용"으로 승인하지 않으면 화면 잠금 중 위치 업데이트 자체가 제한될 수 있다.

### 3. Dart 위치 스트림 또는 timer 지연

발생 가능성: 중간

근거:

- iOS 화면 잠금 상태에서 Dart isolate 실행은 foreground와 동일하게 보장되지 않는다.
- 현재 iOS 네이티브 `CLLocationManager` 경로가 존재하므로 핵심 러닝 유지 로직은 가능한 한 네이티브 경로와 함께 동작해야 한다.

## 6. 최종 원인

최종 원인은 iOS 잠금/백그라운드 상태에서 split TTS 안내가 `flutter_tts` 중심 경로에 의존할 수 있었고, Dart에서 iOS 네이티브 `AVSpeechSynthesizer` 백그라운드 안내 경로로 명시적으로 위임하지 않았던 점이다.

화면이 켜진 상태에서는 Flutter plugin TTS가 정상 출력되지만, 화면 잠금 상태에서는 iOS 오디오/백그라운드 제한 때문에 같은 방식이 안정적으로 동작하지 않을 수 있다.

## 7. 해결 방안

iOS에서 앱이 foreground가 아닐 때는 `flutter_tts`를 직접 호출하지 않고 `run_live_activity` MethodChannel의 `announceSplitInBackground`를 통해 네이티브 `AVSpeechSynthesizer`로 안내하도록 변경했다.

네이티브 플러그인에는 다음 처리를 추가했다.

- `announceSplitInBackground` MethodChannel 메서드 추가
- Dart에서 전달한 `speech`, `completedKm`, `elapsedSeconds` 수신
- `AVAudioSession.playback` 설정 후 `AVSpeechSynthesizer`로 음성 안내
- 네이티브의 `lastAnnouncedSplitKm`, `lastAnnouncedSplitElapsedSeconds`를 갱신해 중복 안내 가능성 감소
- 기존 네이티브 위치 기반 `maybeAnnounceSplit()`도 같은 `speakSplitAnnouncement()` helper를 사용하도록 정리

## 8. 수정한 파일

### `lib/main/running_map_page.dart`

변경 내용:

- `_announceSplitIfNeeded()`에서 앱이 foreground가 아닐 때 플랫폼별 백그라운드 안내 경로를 사용하도록 변경했다.
- Android는 기존 문자열 인자 방식 유지.
- iOS는 `{ speech, completedKm, elapsedSeconds }` map을 MethodChannel로 전달한다.
- iOS 잠금 상태에서 `flutter_tts` 직접 호출을 피하고 네이티브 TTS로 위임한다.

### `ios/Runner/RunLiveActivityPlugin.swift`

변경 내용:

- `announceSplitInBackground` MethodChannel case를 추가했다.
- `announceSplitInBackground(call:result:)` 메서드를 추가했다.
- `speakSplitAnnouncement(_:)` helper를 추가해 iOS 네이티브 chime + speech 로직을 공통화했다.
- Dart에서 받은 split 상태를 네이티브 마지막 안내 상태에도 반영한다.

## 9. 검증 및 테스트 결과

실행한 검증:

- `flutter analyze lib/main/running_map_page.dart`
  - 결과: 통과
- `flutter test test/run_session_engine_test.dart`
  - 결과: 통과
- `xcodebuild -workspace Runner.xcworkspace -scheme Runner -sdk iphonesimulator -configuration Debug -destination generic/platform=iOS Simulator CODE_SIGNING_ALLOWED=NO build`
  - 결과: `BUILD SUCCEEDED`

주의:

- 실제 iPhone에서 화면 잠금 상태로 이동하며 1km 도달 시 음성이 출력되는지는 물리 기기 테스트가 필요하다.
- 시뮬레이터 빌드는 Swift/MethodChannel 컴파일 안정성 검증이며, 실제 잠금화면 GPS/TTS 검증을 대체하지 않는다.

## 10. 실기기 검증 계획

### 1. 기본 foreground TTS 테스트

- iOS 기기에서 앱 실행
- 위치 권한 허용
- 러닝 시작
- 화면이 켜진 상태에서 1km 도달
- 페이스 TTS 출력 확인

### 2. 화면 잠금 TTS 테스트

- 러닝 시작
- 화면 잠금
- 1km 또는 다음 split 지점 도달
- 잠금 상태에서 페이스 TTS 출력 확인

### 3. 백그라운드 전환 테스트

- 러닝 시작
- 다른 앱으로 전환
- 일정 거리 이동
- 1km 도달 시 페이스 TTS 출력 확인

### 4. 위치 권한 테스트

- 위치 권한이 "앱 사용 중"일 때 동작 확인
- 위치 권한이 "항상 허용"일 때 동작 확인
- "항상 허용"이 아닌 경우 화면 잠금 중 위치/TTS가 제한되는지 확인

### 5. 오디오 테스트

- 무음 모드
- 블루투스 이어폰 연결
- 음악 재생 중
- 볼륨 낮음/높음
- 각 상태에서 TTS 출력 여부 확인

### 6. 장시간 러닝 테스트

- 30분 이상 화면 잠금 상태로 러닝
- 1km, 2km, 3km 이상 split 안내 지속 여부 확인
- 앱 복귀 후 거리, 시간, 페이스, 경로가 정상 반영되는지 확인

### 7. 회귀 테스트

- 러닝 시작/일시정지/재개/종료
- 기록 저장
- 지도 경로 표시
- split 계산
- 점령 면적 계산
- 포인트 반영
- Live Activity 표시와 잠금화면 action 동작

## 11. 남은 확인 사항

- 실제 iOS 기기에서 Always location 권한 승인 플로우가 사용자에게 자연스럽게 안내되는지 확인이 필요하다.
- 화면 잠금 중 네이티브 `CLLocationManager` 경로와 Dart `Geolocator` 경로가 동시에 split을 감지할 수 있으므로 중복 안내 여부를 실기기에서 확인해야 한다.
- 현재 수정은 중복 방지를 위해 Dart에서 전달한 split 상태를 네이티브 마지막 안내 상태에 반영하지만, 실제 GPS 이벤트 순서에 따라 경계 상황은 추가 검증이 필요하다.
- iOS 백그라운드 오디오 정책상 무음 모드, 이어폰, 다른 오디오 앱과의 상호작용은 기기별로 반드시 확인해야 한다.
