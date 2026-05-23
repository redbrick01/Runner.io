import ActivityKit
import Foundation
import HealthKit

@available(iOS 16.2, *)
enum RunLiveActivityManager {
    static func start(
        runID: String,
        title: String,
        elapsedSeconds: Int,
        distanceMeters: Double,
        paceText: String,
        isPaused: Bool,
        countdownEndDate: Date? = nil
    ) async throws -> String {
        let attributes = RunLiveActivityAttributes(runID: runID, title: title)
        let state = RunLiveActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            distanceMeters: distanceMeters,
            paceText: paceText,
            status: countdownEndDate == nil ? (isPaused ? .paused : .running) : .countdown,
            countdownEndDate: countdownEndDate
        )

        if let activity = existingActivity(for: runID) {
            await activity.update(ActivityContent(state: state, staleDate: nil))
            return activity.id
        }

        let activity = try Activity<RunLiveActivityAttributes>.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )

        return activity.id
    }

    static func update(
        runID: String,
        elapsedSeconds: Int,
        distanceMeters: Double,
        paceText: String,
        isPaused: Bool,
        countdownEndDate: Date? = nil
    ) async {
        guard let activity = existingActivity(for: runID) else {
            return
        }

        let updatedState = RunLiveActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            distanceMeters: distanceMeters,
            paceText: paceText,
            status: countdownEndDate == nil ? (isPaused ? .paused : .running) : .countdown,
            countdownEndDate: countdownEndDate
        )

        await activity.update(ActivityContent(state: updatedState, staleDate: nil))
    }

    static func end(runID: String, status: RunLiveActivityAttributes.RunStatus) async {
        guard let activity = existingActivity(for: runID) else {
            return
        }

        let endedState = RunLiveActivityAttributes.ContentState(
            elapsedSeconds: activity.content.state.elapsedSeconds,
            distanceMeters: activity.content.state.distanceMeters,
            paceText: activity.content.state.paceText,
            status: status,
            countdownEndDate: nil
        )

        await activity.end(
            ActivityContent(state: endedState, staleDate: nil),
            dismissalPolicy: .immediate
        )
    }

    static func existingActivity(for runID: String) -> Activity<RunLiveActivityAttributes>? {
        Activity<RunLiveActivityAttributes>.activities.first { activity in
            activity.attributes.runID == runID
        }
    }
}

@available(iOS 26.0, *)
@MainActor
final class RunWorkoutSessionManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    static let shared = RunWorkoutSessionManager()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var stopContinuation: CheckedContinuation<Void, Error>?

    private override init() {
        super.init()
    }

    func requestAuthorizationIfNeeded() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw RunWorkoutSessionError.healthDataUnavailable
        }

        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: RunWorkoutSessionError.authorizationDenied)
                }
            }
        }
    }

    func startOrResumeWorkout(isPaused: Bool) async throws {
        try await requestAuthorizationIfNeeded()

        if let session {
            try syncPauseState(isPaused)
            if session.state != .ended {
                return
            }

            cleanup()
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()

        session.delegate = self
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        self.session = session
        self.builder = builder

        let startDate = Date()
        session.startActivity(with: startDate)
        try await builder.beginCollection(at: startDate)

        if isPaused {
            session.pause()
        }
    }

    func syncPauseState(_ isPaused: Bool) throws {
        guard let session else {
            return
        }

        switch session.state {
        case .running where isPaused:
            session.pause()
        case .paused where !isPaused:
            session.resume()
        default:
            break
        }
    }

    func endWorkout(save: Bool) async {
        guard let session, let builder else {
            cleanup()
            return
        }

        if save {
            let endDate = Date()

            do {
                session.stopActivity(with: endDate)
                try await waitUntilStopped()
                try await builder.endCollection(at: endDate)
                _ = try await builder.finishWorkout()
                session.end()
            } catch {
                session.end()
            }
        } else {
            session.end()
            builder.discardWorkout()
        }

        cleanup()
    }

    private func waitUntilStopped() async throws {
        guard let session else {
            return
        }

        if session.state == .stopped {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stopContinuation = continuation
        }
    }

    private func cleanup() {
        stopContinuation = nil
        session = nil
        builder = nil
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            if toState == .stopped {
                stopContinuation?.resume()
                stopContinuation = nil
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            stopContinuation?.resume(throwing: error)
            cleanup()
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {}
}

@available(iOS 26.0, *)
private enum RunWorkoutSessionError: LocalizedError {
    case healthDataUnavailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "HealthKit is unavailable on this device."
        case .authorizationDenied:
            return "HealthKit authorization is required to keep workouts active in the background."
        }
    }
}
