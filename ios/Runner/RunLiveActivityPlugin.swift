import Flutter
import Foundation
import AVFoundation
import CoreLocation
import UIKit

final class RunLiveActivityPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate, AVSpeechSynthesizerDelegate {
    private static let channelName = "run_live_activity"
    private static let splitAnnouncementDistanceMeters = 500.0
    private static var channel: FlutterMethodChannel?
    private static var actionObserver: NSObjectProtocol?
    private let locationManager = CLLocationManager()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var chimeEngine: AVAudioEngine?
    private var chimeNode: AVAudioPlayerNode?
    private var countdownBackgroundTask: UIBackgroundTaskIdentifier = .invalid

    private var trackingRunID: String?
    private var trackingDistanceMeters: Double = 0
    private var trackingStartedAt: Date?
    private var trackingPausedDuration: TimeInterval = 0
    private var trackingPausedAt: Date?
    private var trackingIsPaused: Bool = false
    private var lastLocation: CLLocation?
    private var lastAnnouncedSplitKm: Int = 0
    private var lastAnnouncedSplitElapsedSeconds: Int = 0
    private var isSplitTrackingActive = false
    private var lastSyncedFlutterDistanceMeters: Double = 0
    private var lastNativeLocationUpdateAt: Date?
    private var lastSplitAnnouncementAt: Date?
    private var lastAudioSessionError: String?
    private var lastLocationError: String?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = RunLiveActivityPlugin()
        instance.locationManager.delegate = instance
        instance.locationManager.activityType = .fitness
        instance.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        instance.locationManager.distanceFilter = 3
        instance.locationManager.pausesLocationUpdatesAutomatically = false
        instance.locationManager.allowsBackgroundLocationUpdates = true
        instance.speechSynthesizer.delegate = instance
        registrar.addMethodCallDelegate(instance, channel: channel)

        self.channel = channel

        if actionObserver == nil {
            actionObserver = NotificationCenter.default.addObserver(
                forName: RunLiveActivityStore.actionNotification,
                object: nil,
                queue: .main
            ) { _ in
                guard let payload = RunLiveActivityStore.currentPendingAction() else {
                    return
                }

                self.channel?.invokeMethod("onLiveActivityAction", arguments: payload.dictionary)
            }
        }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestHealthKitAuthorization":
            requestHealthKitAuthorization(result: result)
        case "startLiveActivity":
            startLiveActivity(call: call, result: result)
        case "updateLiveActivity":
            updateLiveActivity(call: call, result: result)
        case "endLiveActivity":
            endLiveActivity(call: call, result: result)
        case "consumePendingAction":
            result(RunLiveActivityStore.consumePendingAction()?.dictionary)
        case "clearPendingAction":
            RunLiveActivityStore.clearPendingAction()
            result(nil)
        case "playSplitChime":
            playSplitChime(result: result)
        case "announceSplitInBackground":
            announceSplitInBackground(call: call, result: result)
        case "startIosSplitTracking":
            startIosSplitTracking(call: call, result: result)
        case "updateIosSplitTracking":
            updateIosSplitTracking(call: call, result: result)
        case "stopIosSplitTracking":
            stopIosSplitTracking(result: result)
        case "getIosSplitTrackingStatus":
            getIosSplitTrackingStatus(result: result)
        case "beginCountdownBackgroundTask":
            beginCountdownBackgroundTask(result: result)
        case "endCountdownBackgroundTask":
            endCountdownBackgroundTask(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func playSplitChime(result: @escaping FlutterResult) {
        playSynthChime()
        result(nil)
    }

    private func announceSplitInBackground(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let speech: String
        var completedKm: Int?
        var elapsedSeconds: Int?

        if let args = call.arguments as? [String: Any] {
            speech = (args["speech"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            completedKm = (args["completedKm"] as? NSNumber)?.intValue ?? args["completedKm"] as? Int
            elapsedSeconds = (args["elapsedSeconds"] as? NSNumber)?.intValue ?? args["elapsedSeconds"] as? Int
        } else {
            speech = (call.arguments as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        guard !speech.isEmpty else {
            result(nil)
            return
        }

        guard speakSplitAnnouncement(speech) else {
            result(FlutterError(code: "audio_session_failed", message: lastAudioSessionError, details: nil))
            return
        }
        if let completedKm {
            lastAnnouncedSplitKm = max(lastAnnouncedSplitKm, completedKm)
        }
        if let elapsedSeconds {
            lastAnnouncedSplitElapsedSeconds = max(lastAnnouncedSplitElapsedSeconds, elapsedSeconds)
        }
        result(nil)
    }

    private func beginCountdownBackgroundTask(result: @escaping FlutterResult) {
        endCountdownBackgroundTaskInternal()
        countdownBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "run_countdown_task") { [weak self] in
            self?.endCountdownBackgroundTaskInternal()
        }
        result(nil)
    }

    private func endCountdownBackgroundTask(result: @escaping FlutterResult) {
        endCountdownBackgroundTaskInternal()
        result(nil)
    }

    private func endCountdownBackgroundTaskInternal() {
        guard countdownBackgroundTask != .invalid else {
            return
        }
        UIApplication.shared.endBackgroundTask(countdownBackgroundTask)
        countdownBackgroundTask = .invalid
    }

    private func playSynthChime() {
        guard configureBackgroundSpeechAudioSession() else { return }
        playSineTone(
            frequency: 1320.0,
            duration: 0.13,
            volume: 0.9
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            if !self.isSplitTrackingActive && !self.speechSynthesizer.isSpeaking {
                self.deactivateSpeechAudioSession()
            }
        }
    }

    private func playSineTone(frequency: Double, duration: Double, volume: Float) {
        let sampleRate = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard frameCount > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData?[0] else {
            return
        }

        buffer.frameLength = frameCount
        let theta = 2.0 * Double.pi * frequency / sampleRate
        var phase = 0.0
        for frame in 0 ..< Int(frameCount) {
            // Apply a quick fade-out to avoid click noise.
            let fade = max(0.0, 1.0 - (Double(frame) / Double(frameCount)))
            channelData[frame] = Float(sin(phase) * fade)
            phase += theta
        }

        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        node.volume = volume

        do {
            try engine.start()
        } catch {
            lastAudioSessionError = "chime engine: \(error.localizedDescription)"
            NSLog("Failed to start chime engine: \(error.localizedDescription)")
            return
        }

        NSLog("[iOS Split TTS] play chime")
        chimeEngine = engine
        chimeNode = node
        node.scheduleBuffer(buffer, at: nil, options: .interrupts) { [weak self] in
            DispatchQueue.main.async {
                self?.chimeNode?.stop()
                self?.chimeEngine?.stop()
                self?.chimeNode = nil
                self?.chimeEngine = nil
            }
        }
        node.play()
    }

    private func requestHealthKitAuthorization(result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(FlutterError(code: "unsupported_ios", message: "HealthKit workout sessions require iOS 26.0 or later.", details: nil))
            return
        }

        Task { @MainActor in
            do {
                try await RunWorkoutSessionManager.shared.requestAuthorizationIfNeeded()
                result(true)
            } catch {
                result(FlutterError(code: "healthkit_auth_failed", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func startLiveActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            result(FlutterError(code: "unsupported_ios", message: "Live Activities require iOS 16.2 or later.", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let runID = args["runId"] as? String,
              let elapsedSeconds = args["elapsedSeconds"] as? Int,
              let paceText = args["paceText"] as? String else {
            result(FlutterError(code: "invalid_args", message: "Missing required startLiveActivity arguments.", details: nil))
            return
        }

        let title = (args["title"] as? String)?.isEmpty == false ? (args["title"] as? String ?? "") : "러닝 중"
        let distanceMeters = args["distanceMeters"] as? Double ?? 0
        let isPaused = args["isPaused"] as? Bool ?? false

        Task { @MainActor in
            do {
                if #available(iOS 26.0, *) {
                    do {
                        try await RunWorkoutSessionManager.shared.startOrResumeWorkout(isPaused: isPaused)
                    } catch {
                        NSLog("HealthKit workout start skipped: \(error.localizedDescription)")
                    }
                }

                let activityID = try await RunLiveActivityManager.start(
                    runID: runID,
                    title: title,
                    elapsedSeconds: elapsedSeconds,
                    distanceMeters: distanceMeters,
                    paceText: paceText,
                    isPaused: isPaused,
                    countdownEndDate: nil
                )
                if UIApplication.shared.applicationState != .active && !isPaused && elapsedSeconds <= 1 {
                    playSynthChime()
                }
                result(activityID)
            } catch {
                result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func updateLiveActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            result(FlutterError(code: "unsupported_ios", message: "Live Activities require iOS 16.2 or later.", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let runID = args["runId"] as? String,
              let elapsedSeconds = args["elapsedSeconds"] as? Int,
              let paceText = args["paceText"] as? String else {
            result(FlutterError(code: "invalid_args", message: "Missing required updateLiveActivity arguments.", details: nil))
            return
        }

        let distanceMeters = args["distanceMeters"] as? Double ?? 0
        let isPaused = args["isPaused"] as? Bool ?? false

        Task { @MainActor in
            if #available(iOS 26.0, *) {
                do {
                    try RunWorkoutSessionManager.shared.syncPauseState(isPaused)
                } catch {
                    NSLog("HealthKit pause sync skipped: \(error.localizedDescription)")
                }
            }

            await RunLiveActivityManager.update(
                runID: runID,
                elapsedSeconds: elapsedSeconds,
                distanceMeters: distanceMeters,
                paceText: paceText,
                isPaused: isPaused,
                countdownEndDate: nil
            )
            result(nil)
        }
    }

    private func endLiveActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            result(FlutterError(code: "unsupported_ios", message: "Live Activities require iOS 16.2 or later.", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let runID = args["runId"] as? String else {
            result(FlutterError(code: "invalid_args", message: "Missing required endLiveActivity arguments.", details: nil))
            return
        }

        let rawStatus = args["status"] as? String ?? "ended"
        let status = RunLiveActivityAttributes.RunStatus(rawValue: rawStatus) ?? .ended

        Task { @MainActor in
            if #available(iOS 26.0, *) {
                await RunWorkoutSessionManager.shared.endWorkout(save: status != .cancelled)
            }

            await RunLiveActivityManager.end(runID: runID, status: status)
            result(nil)
        }
    }

    private struct SplitTrackingPayload {
        let runID: String
        let elapsedSeconds: Int
        let distanceMeters: Double
        let isPaused: Bool
        let lastAnnouncedSplitKm: Int
        let lastAnnouncedSplitElapsedSeconds: Int
        let lifecycleState: String
    }

    private func parseSplitTrackingPayload(_ arguments: Any?) -> SplitTrackingPayload? {
        guard let args = arguments as? [String: Any],
              let runID = args["runId"] as? String,
              let elapsedSeconds = (args["elapsedSeconds"] as? NSNumber)?.intValue ?? args["elapsedSeconds"] as? Int else {
            return nil
        }

        let distanceMeters = (args["distanceMeters"] as? NSNumber)?.doubleValue
            ?? args["distanceMeters"] as? Double
            ?? 0
        let isPaused = (args["isPaused"] as? NSNumber)?.boolValue
            ?? args["isPaused"] as? Bool
            ?? false
        let lastAnnouncedSplitKm = (args["lastAnnouncedSplitKm"] as? NSNumber)?.intValue
            ?? args["lastAnnouncedSplitKm"] as? Int
            ?? 0
        let lastAnnouncedSplitElapsedSeconds = (args["lastAnnouncedSplitElapsedSeconds"] as? NSNumber)?.intValue
            ?? args["lastAnnouncedSplitElapsedSeconds"] as? Int
            ?? 0
        let lifecycleState = args["lifecycleState"] as? String ?? "unknown"

        return SplitTrackingPayload(
            runID: runID,
            elapsedSeconds: elapsedSeconds,
            distanceMeters: distanceMeters,
            isPaused: isPaused,
            lastAnnouncedSplitKm: lastAnnouncedSplitKm,
            lastAnnouncedSplitElapsedSeconds: lastAnnouncedSplitElapsedSeconds,
            lifecycleState: lifecycleState
        )
    }

    private func startIosSplitTracking(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let payload = parseSplitTrackingPayload(call.arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing required startIosSplitTracking arguments.", details: nil))
            return
        }

        configureSplitTracking(
            runID: payload.runID,
            elapsedSeconds: payload.elapsedSeconds,
            distanceMeters: payload.distanceMeters,
            isPaused: payload.isPaused,
            lastAnnouncedSplitKm: payload.lastAnnouncedSplitKm,
            lastAnnouncedSplitElapsedSeconds: payload.lastAnnouncedSplitElapsedSeconds
        )
        NSLog("[iOS Split TTS] start tracking runId=\(payload.runID) distance=\(payload.distanceMeters) elapsed=\(payload.elapsedSeconds) lifecycle=\(payload.lifecycleState)")
        result(nil)
    }

    private func updateIosSplitTracking(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let payload = parseSplitTrackingPayload(call.arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing required updateIosSplitTracking arguments.", details: nil))
            return
        }

        updateSplitTracking(
            runID: payload.runID,
            elapsedSeconds: payload.elapsedSeconds,
            distanceMeters: payload.distanceMeters,
            isPaused: payload.isPaused,
            lastAnnouncedSplitKm: payload.lastAnnouncedSplitKm,
            lastAnnouncedSplitElapsedSeconds: payload.lastAnnouncedSplitElapsedSeconds
        )
        result(nil)
    }

    private func stopIosSplitTracking(result: @escaping FlutterResult) {
        NSLog("[iOS Split TTS] stop tracking runId=\(trackingRunID ?? "nil")")
        stopSplitTracking()
        result(nil)
    }

    private func getIosSplitTrackingStatus(result: @escaping FlutterResult) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        result([
            "runId": channelValue(trackingRunID),
            "isTracking": isSplitTrackingActive,
            "isPaused": trackingIsPaused,
            "trackingDistanceMeters": trackingDistanceMeters,
            "lastSyncedFlutterDistanceMeters": lastSyncedFlutterDistanceMeters,
            "lastAnnouncedSplitKm": lastAnnouncedSplitKm,
            "lastAnnouncedSplitElapsedSeconds": lastAnnouncedSplitElapsedSeconds,
            "lastNativeLocationUpdateAt": channelValue(lastNativeLocationUpdateAt?.timeIntervalSince1970),
            "lastSplitAnnouncementAt": channelValue(lastSplitAnnouncementAt?.timeIntervalSince1970),
            "authorizationStatus": authorizationStatusDescription(status),
            "lastAudioSessionError": channelValue(lastAudioSessionError),
            "lastLocationError": channelValue(lastLocationError)
        ])
    }

    private func channelValue(_ value: Any?) -> Any {
        value ?? NSNull()
    }

    private func configureSplitTracking(
        runID: String,
        elapsedSeconds: Int,
        distanceMeters: Double,
        isPaused: Bool,
        lastAnnouncedSplitKm: Int,
        lastAnnouncedSplitElapsedSeconds: Int
    ) {
        isSplitTrackingActive = true
        trackingRunID = runID
        trackingDistanceMeters = max(0, distanceMeters)
        lastSyncedFlutterDistanceMeters = max(0, distanceMeters)
        trackingStartedAt = Date().addingTimeInterval(-TimeInterval(max(0, elapsedSeconds)))
        trackingPausedDuration = 0
        trackingPausedAt = isPaused ? Date() : nil
        trackingIsPaused = isPaused
        lastLocation = nil
        self.lastAnnouncedSplitKm = max(0, lastAnnouncedSplitKm)
        self.lastAnnouncedSplitElapsedSeconds = max(0, lastAnnouncedSplitElapsedSeconds)
        lastNativeLocationUpdateAt = nil
        lastSplitAnnouncementAt = nil
        lastAudioSessionError = nil
        lastLocationError = nil

        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        NSLog("[iOS Split TTS] authorization status=\(authorizationStatusDescription(status))")
        if status == .notDetermined || status == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
        locationManager.startUpdatingLocation()
    }

    private func updateSplitTracking(
        runID: String,
        elapsedSeconds: Int,
        distanceMeters: Double,
        isPaused: Bool,
        lastAnnouncedSplitKm: Int,
        lastAnnouncedSplitElapsedSeconds: Int
    ) {
        guard trackingRunID == runID else {
            configureSplitTracking(
                runID: runID,
                elapsedSeconds: elapsedSeconds,
                distanceMeters: distanceMeters,
                isPaused: isPaused,
                lastAnnouncedSplitKm: lastAnnouncedSplitKm,
                lastAnnouncedSplitElapsedSeconds: lastAnnouncedSplitElapsedSeconds
            )
            return
        }

        isSplitTrackingActive = true
        lastSyncedFlutterDistanceMeters = max(lastSyncedFlutterDistanceMeters, distanceMeters)
        trackingDistanceMeters = max(trackingDistanceMeters, distanceMeters)
        self.lastAnnouncedSplitKm = max(self.lastAnnouncedSplitKm, lastAnnouncedSplitKm)
        self.lastAnnouncedSplitElapsedSeconds = max(
            self.lastAnnouncedSplitElapsedSeconds,
            lastAnnouncedSplitElapsedSeconds
        )
        if trackingStartedAt == nil {
            trackingStartedAt = Date().addingTimeInterval(-TimeInterval(max(0, elapsedSeconds)))
        }
        if isPaused != trackingIsPaused {
            if isPaused {
                trackingPausedAt = Date()
            } else if let pausedAt = trackingPausedAt {
                trackingPausedDuration += Date().timeIntervalSince(pausedAt)
                trackingPausedAt = nil
            }
            trackingIsPaused = isPaused
        }
        maybeAnnounceSplit()
    }

    private func stopSplitTracking() {
        endCountdownBackgroundTaskInternal()
        locationManager.stopUpdatingLocation()
        isSplitTrackingActive = false
        trackingRunID = nil
        trackingDistanceMeters = 0
        lastSyncedFlutterDistanceMeters = 0
        trackingStartedAt = nil
        trackingPausedDuration = 0
        trackingPausedAt = nil
        trackingIsPaused = false
        lastLocation = nil
        lastAnnouncedSplitKm = 0
        lastAnnouncedSplitElapsedSeconds = 0
        lastNativeLocationUpdateAt = nil
        lastSplitAnnouncementAt = nil
        lastAudioSessionError = nil
        lastLocationError = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
        deactivateSpeechAudioSession()
        chimeNode?.stop()
        chimeEngine?.stop()
        chimeNode = nil
        chimeEngine = nil
    }

    private func effectiveElapsedSeconds() -> Int {
        guard let startedAt = trackingStartedAt else { return 0 }
        var paused = trackingPausedDuration
        if trackingIsPaused, let pausedAt = trackingPausedAt {
            paused += Date().timeIntervalSince(pausedAt)
        }
        let elapsed = Date().timeIntervalSince(startedAt) - paused
        return max(0, Int(elapsed.rounded(.down)))
    }

    private func maybeAnnounceSplit() {
        guard isSplitTrackingActive else { return }
        if UIApplication.shared.applicationState == .active {
            return
        }
        let completedKm = Int((trackingDistanceMeters / Self.splitAnnouncementDistanceMeters).rounded(.down))
        guard completedKm > lastAnnouncedSplitKm else { return }
        let elapsedNow = effectiveElapsedSeconds()
        let splitDuration = max(0, elapsedNow - lastAnnouncedSplitElapsedSeconds)
        let splitPaceSeconds = Self.splitAnnouncementDistanceMeters > 0
            ? Int((Double(splitDuration) / (Self.splitAnnouncementDistanceMeters / 1000.0)).rounded())
            : 0
        let splitText = formatSplitPaceKorean(splitPaceSeconds)
        let announcedMeters = Int((Double(completedKm) * Self.splitAnnouncementDistanceMeters).rounded())
        let speech = "\(announcedMeters)미터, 구간 페이스 \(splitText)"
        NSLog("[iOS Split TTS] announce split km=\(completedKm) distance=\(trackingDistanceMeters) elapsed=\(elapsedNow)")
        guard speakSplitAnnouncement(speech) else { return }
        lastAnnouncedSplitKm = completedKm
        lastAnnouncedSplitElapsedSeconds = elapsedNow
        lastSplitAnnouncementAt = Date()
    }

    private func speakSplitAnnouncement(_ speech: String) -> Bool {
        guard configureBackgroundSpeechAudioSession() else { return false }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.playSplitChime(result: { _ in })
            let utterance = AVSpeechUtterance(string: speech)
            utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
            utterance.rate = 0.46
            utterance.pitchMultiplier = 1.0
            NSLog("[iOS Split TTS] speak start text=\(speech)")
            self.speechSynthesizer.speak(utterance)
        }
        return true
    }

    @discardableResult
    private func configureBackgroundSpeechAudioSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try session.setActive(true)
            lastAudioSessionError = nil
            NSLog("[iOS Split TTS] audio session active")
            return true
        } catch {
            lastAudioSessionError = error.localizedDescription
            NSLog("Failed to configure AVAudioSession for background speech: \(error.localizedDescription)")
            return false
        }
    }

    private func deactivateSpeechAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            NSLog("Failed to deactivate AVAudioSession: \(error.localizedDescription)")
        }
    }

    private func authorizationStatusDescription(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorizedAlways"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        @unknown default:
            return "unknown"
        }
    }

    private func formatSplitPaceKorean(_ secondsPerKm: Int) -> String {
        guard secondsPerKm > 0 else { return "측정 불가" }
        let minutes = secondsPerKm / 60
        let seconds = secondsPerKm % 60
        return "\(minutes)분 \(String(format: "%02d", seconds))초"
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isSplitTrackingActive, trackingRunID != nil, !trackingIsPaused else { return }
        for location in locations {
            if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 25 {
                continue
            }
            lastNativeLocationUpdateAt = location.timestamp
            guard let previous = lastLocation else {
                lastLocation = location
                continue
            }
            let distance = location.distance(from: previous)
            if distance < 3 {
                continue
            }
            let timeDelta = location.timestamp.timeIntervalSince(previous.timestamp)
            if timeDelta > 0 {
                let speed = distance / timeDelta
                if speed > 30 {
                    continue
                }
            }
            trackingDistanceMeters += distance
            lastLocation = location
            maybeAnnounceSplit()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastLocationError = error.localizedDescription
        NSLog("Run split location update failed: \(error.localizedDescription)")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        NSLog("[iOS Split TTS] speech finished")
        deactivateSpeechAudioSession()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        NSLog("[iOS Split TTS] speech cancelled")
        deactivateSpeechAudioSession()
    }
}
