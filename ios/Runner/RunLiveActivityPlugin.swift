import Flutter
import Foundation
import AVFoundation
import CoreLocation
import UIKit

final class RunLiveActivityPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate, AVSpeechSynthesizerDelegate {
    private static let channelName = "run_live_activity"
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
        configureBackgroundSpeechAudioSession()
        playSineTone(
            frequency: 1320.0,
            duration: 0.13,
            volume: 0.9
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            if !self.speechSynthesizer.isSpeaking {
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
            NSLog("Failed to start chime engine: \(error.localizedDescription)")
            return
        }

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
                configureSplitTracking(
                    runID: runID,
                    elapsedSeconds: elapsedSeconds,
                    distanceMeters: distanceMeters,
                    isPaused: isPaused
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
            updateSplitTracking(
                runID: runID,
                elapsedSeconds: elapsedSeconds,
                distanceMeters: distanceMeters,
                isPaused: isPaused
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
            stopSplitTracking()
            result(nil)
        }
    }

    private func configureSplitTracking(
        runID: String,
        elapsedSeconds: Int,
        distanceMeters: Double,
        isPaused: Bool
    ) {
        trackingRunID = runID
        trackingDistanceMeters = max(0, distanceMeters)
        trackingStartedAt = Date().addingTimeInterval(-TimeInterval(max(0, elapsedSeconds)))
        trackingPausedDuration = 0
        trackingPausedAt = isPaused ? Date() : nil
        trackingIsPaused = isPaused
        lastLocation = nil
        lastAnnouncedSplitKm = Int((trackingDistanceMeters / 1000.0).rounded(.down))
        lastAnnouncedSplitElapsedSeconds = max(0, elapsedSeconds)

        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        if status == .notDetermined || status == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
        configureBackgroundSpeechAudioSession()
        locationManager.startUpdatingLocation()
    }

    private func updateSplitTracking(
        runID: String,
        elapsedSeconds: Int,
        distanceMeters: Double,
        isPaused: Bool
    ) {
        guard trackingRunID == runID else {
            configureSplitTracking(
                runID: runID,
                elapsedSeconds: elapsedSeconds,
                distanceMeters: distanceMeters,
                isPaused: isPaused
            )
            return
        }

        trackingDistanceMeters = max(trackingDistanceMeters, distanceMeters)
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
    }

    private func stopSplitTracking() {
        endCountdownBackgroundTaskInternal()
        locationManager.stopUpdatingLocation()
        trackingRunID = nil
        trackingDistanceMeters = 0
        trackingStartedAt = nil
        trackingPausedDuration = 0
        trackingPausedAt = nil
        trackingIsPaused = false
        lastLocation = nil
        lastAnnouncedSplitKm = 0
        lastAnnouncedSplitElapsedSeconds = 0
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
        if UIApplication.shared.applicationState == .active {
            return
        }
        let completedKm = Int((trackingDistanceMeters / 1000.0).rounded(.down))
        guard completedKm > lastAnnouncedSplitKm else { return }
        let elapsedNow = effectiveElapsedSeconds()
        let splitDuration = max(0, elapsedNow - lastAnnouncedSplitElapsedSeconds)
        lastAnnouncedSplitKm = completedKm
        lastAnnouncedSplitElapsedSeconds = elapsedNow

        let splitText = formatSplitPaceKorean(splitDuration)
        let speech = "\(completedKm)킬로미터, 구간 페이스 \(splitText)"
        playSplitChime(result: { _ in })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self else { return }
            self.configureBackgroundSpeechAudioSession()
            let utterance = AVSpeechUtterance(string: speech)
            utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
            utterance.rate = 0.46
            utterance.pitchMultiplier = 1.0
            self.speechSynthesizer.stopSpeaking(at: .immediate)
            self.speechSynthesizer.speak(utterance)
        }
    }

    private func configureBackgroundSpeechAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers, .interruptSpokenAudioAndMixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true)
        } catch {
            NSLog("Failed to configure AVAudioSession for background speech: \(error.localizedDescription)")
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

    private func formatSplitPaceKorean(_ secondsPerKm: Int) -> String {
        guard secondsPerKm > 0 else { return "측정 불가" }
        let minutes = secondsPerKm / 60
        let seconds = secondsPerKm % 60
        return "\(minutes)분 \(String(format: "%02d", seconds))초"
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard trackingRunID != nil, !trackingIsPaused else { return }
        for location in locations {
            if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 25 {
                continue
            }
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
        NSLog("Run split location update failed: \(error.localizedDescription)")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        deactivateSpeechAudioSession()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        deactivateSpeechAudioSession()
    }
}
