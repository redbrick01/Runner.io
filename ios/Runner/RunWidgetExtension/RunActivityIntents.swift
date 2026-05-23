import ActivityKit
import AppIntents
import Foundation

@available(iOS 17.0, *)
struct PauseRunIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "일시정지"

    @Parameter(title: "Run ID")
    var runID: String

    init() {}

    init(runID: String) {
        self.runID = runID
    }

    func perform() async throws -> some IntentResult {
        RunLiveActivityStore.savePendingAction(.pause, runID: runID)
        return .result()
    }
}

@available(iOS 17.0, *)
struct ResumeRunIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "재개"

    @Parameter(title: "Run ID")
    var runID: String

    init() {}

    init(runID: String) {
        self.runID = runID
    }

    func perform() async throws -> some IntentResult {
        let countdownEndDate = Date().addingTimeInterval(3)
        if #available(iOSApplicationExtension 16.2, *) {
            if let activity = Activity<RunLiveActivityAttributes>.activities.first(where: { $0.attributes.runID == runID }) {
                let state = activity.content.state
                let updatedState = RunLiveActivityAttributes.ContentState(
                    elapsedSeconds: state.elapsedSeconds,
                    distanceMeters: state.distanceMeters,
                    paceText: state.paceText,
                    status: .countdown,
                    countdownEndDate: countdownEndDate
                )

                await activity.update(ActivityContent(state: updatedState, staleDate: countdownEndDate))
            }
        }
        RunLiveActivityStore.savePendingAction(.resume, runID: runID)
        return .result()
    }
}

@available(iOS 17.0, *)
struct StopRunIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "종료"

    @Parameter(title: "Run ID")
    var runID: String

    init() {}

    init(runID: String) {
        self.runID = runID
    }

    func perform() async throws -> some IntentResult {
        RunLiveActivityStore.savePendingAction(.stop, runID: runID)
        return .result()
    }
}

@available(iOS 17.0, *)
struct CancelRunIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "취소"

    @Parameter(title: "Run ID")
    var runID: String

    init() {}

    init(runID: String) {
        self.runID = runID
    }

    func perform() async throws -> some IntentResult {
        RunLiveActivityStore.savePendingAction(.cancel, runID: runID)
        return .result()
    }
}
