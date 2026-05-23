import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct RunLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var distanceMeters: Double
        var paceText: String
        var status: RunStatus
        var countdownEndDate: Date?
    }

    enum RunStatus: String, Codable, Hashable {
        case running
        case paused
        case countdown
        case ended
        case cancelled
    }

    let runID: String
    let title: String
}
