import Foundation

enum RunLiveActivityAction: String, Codable {
    case pause
    case resume
    case stop
    case cancel
}

struct RunLiveActivityActionPayload: Codable {
    let action: RunLiveActivityAction
    let runID: String
    let createdAt: Date

    var dictionary: [String: Any] {
        [
            "action": action.rawValue,
            "runId": runID,
            "createdAt": ISO8601DateFormatter().string(from: createdAt)
        ]
    }
}

enum RunLiveActivityStore {
    static let sharedSuiteName = "group.com.example.runnerFlutter.liveactivity"
    static let pendingActionKey = "run_live_activity.pending_action"
    static let actionNotification = Notification.Name("run_live_activity.action_received")

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: sharedSuiteName) ?? .standard
    }

    static func savePendingAction(_ action: RunLiveActivityAction, runID: String) {
        let payload = RunLiveActivityActionPayload(
            action: action,
            runID: runID,
            createdAt: Date()
        )

        guard let data = try? JSONEncoder().encode(payload) else {
            return
        }

        defaults.set(data, forKey: pendingActionKey)
        NotificationCenter.default.post(name: actionNotification, object: nil)
    }

    static func currentPendingAction() -> RunLiveActivityActionPayload? {
        guard let data = defaults.data(forKey: pendingActionKey) else {
            return nil
        }

        return try? JSONDecoder().decode(RunLiveActivityActionPayload.self, from: data)
    }

    static func consumePendingAction() -> RunLiveActivityActionPayload? {
        let payload = currentPendingAction()
        clearPendingAction()
        return payload
    }

    static func clearPendingAction() {
        defaults.removeObject(forKey: pendingActionKey)
    }
}
