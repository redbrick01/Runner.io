import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct RunWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOSApplicationExtension 17.0, *) {
            RunLiveActivityWidget()
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
struct RunLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunLiveActivityAttributes.self) { context in
            RunLockScreenView(context: context)
                .activityBackgroundTint(RunActivityPalette.background)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RunExpandedStatusView(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    RunExpandedTimerView(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    RunDynamicIslandExpandedContent(context: context)
                }
            } compactLeading: {
                RunCompactLeadingView(context: context)
            } compactTrailing: {
                RunCompactTrailingView(context: context)
            } minimal: {
                dynamicIslandStatusIcon(context: context)
            }
            .widgetURL(URL(string: "runnerflutter://run/\(context.attributes.runID)"))
            .keylineTint(RunActivityPalette.accent)
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
private enum RunActivityPalette {
    static let background = Color(red: 0.04, green: 0.10, blue: 0.19)
    static let backgroundTop = Color(red: 0.08, green: 0.16, blue: 0.28)
    static let accent = Color(red: 0.24, green: 0.68, blue: 0.93)
    static let accentSoft = Color(red: 0.35, green: 0.74, blue: 0.94)
    static let accentDeep = Color(red: 0.08, green: 0.38, blue: 0.67)
    static let destructive = Color(red: 0.09, green: 0.31, blue: 0.55)
    static let surface = Color.white.opacity(0.08)
    static let border = Color.white.opacity(0.12)
    static let secondaryText = Color.white.opacity(0.70)
}

@available(iOSApplicationExtension 17.0, *)
private func formattedDuration(for context: ActivityViewContext<RunLiveActivityAttributes>) -> String {
    let hours = context.state.elapsedSeconds / 3600
    let minutes = (context.state.elapsedSeconds % 3600) / 60
    let seconds = context.state.elapsedSeconds % 60

    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}

@available(iOSApplicationExtension 17.0, *)
private func distanceText(for context: ActivityViewContext<RunLiveActivityAttributes>) -> String {
    String(format: "%.2fkm", context.state.distanceMeters / 1000)
}

@available(iOSApplicationExtension 17.0, *)
private func countdownEndDate(for context: ActivityViewContext<RunLiveActivityAttributes>) -> Date? {
    guard context.state.status == .countdown else {
        return nil
    }
    return context.state.countdownEndDate
}

@available(iOSApplicationExtension 17.0, *)
private func isCountdownActive(for context: ActivityViewContext<RunLiveActivityAttributes>) -> Bool {
    guard let countdownEndDate = countdownEndDate(for: context) else {
        return false
    }
    return countdownEndDate > Date()
}

@available(iOSApplicationExtension 17.0, *)
private func runStatusTitle(for context: ActivityViewContext<RunLiveActivityAttributes>) -> String {
    switch context.state.status {
    case .running:
        return "Running"
    case .paused:
        return "Paused"
    case .countdown:
        return "Starting"
    case .ended:
        return "Completed"
    case .cancelled:
        return "Cancelled"
    }
}

@available(iOSApplicationExtension 17.0, *)
private func runStatusColor(for context: ActivityViewContext<RunLiveActivityAttributes>) -> Color {
    switch context.state.status {
    case .running:
        return RunActivityPalette.accent
    case .paused:
        return RunActivityPalette.accentSoft
    case .countdown:
        return .white
    case .ended, .cancelled:
        return RunActivityPalette.secondaryText
    }
}

@available(iOSApplicationExtension 17.0, *)
@ViewBuilder
private func dynamicIslandStatusIcon(context: ActivityViewContext<RunLiveActivityAttributes>) -> some View {
    ZStack {
        Circle()
            .stroke(RunActivityPalette.border, lineWidth: 2)

        Circle()
            .trim(from: 0, to: context.state.status == .paused ? 0.35 : (context.state.status == .countdown ? 1.0 : 0.82))
            .stroke(
                context.state.status == .paused ? RunActivityPalette.accentSoft : (context.state.status == .countdown ? .white : RunActivityPalette.accent),
                style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))

        Image(systemName: context.state.status == .paused ? "pause.fill" : (context.state.status == .countdown ? "timer" : "figure.run"))
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
    }
    .frame(width: 24, height: 24)
}

@available(iOSApplicationExtension 17.0, *)
private struct RunLockScreenView: View {
    let context: ActivityViewContext<RunLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(distanceDisplayText)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 12)

                if let countdownEndDate = countdownEndDate(for: context), isCountdownActive(for: context) {
                    Text(timerInterval: Date()...countdownEndDate, countsDown: true)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text(durationDisplayText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(RunActivityPalette.accentSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            RunLiveActivityActionButtons(context: context)
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            RunActivityPalette.backgroundTop,
                            RunActivityPalette.background
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var durationDisplayText: String {
        formattedDuration(for: context)
    }

    private var distanceDisplayText: String {
        distanceText(for: context)
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct RunDynamicIslandExpandedContent: View {
    let context: ActivityViewContext<RunLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(distanceText(for: context))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 12)

                if let countdownEndDate = countdownEndDate(for: context), isCountdownActive(for: context) {
                    Text(timerInterval: Date()...countdownEndDate, countsDown: true)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text(formattedDuration(for: context))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(RunActivityPalette.accentSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            RunDynamicIslandActionButtons(context: context)
        }
        .padding(.top, 6)
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct RunExpandedStatusView: View {
    let context: ActivityViewContext<RunLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 8) {
            dynamicIslandStatusIcon(context: context)

            Text(runStatusTitle(for: context))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(RunActivityPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct RunExpandedTimerView: View {
    let context: ActivityViewContext<RunLiveActivityAttributes>

    var body: some View {
        Group {
            if let countdownEndDate = countdownEndDate(for: context), isCountdownActive(for: context) {
                Text(timerInterval: Date()...countdownEndDate, countsDown: true)
                    .foregroundStyle(.white)
            } else {
                Text("Pace \(context.state.paceText)")
                    .foregroundStyle(RunActivityPalette.accentSoft)
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct RunCompactLeadingView: View {
    let context: ActivityViewContext<RunLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 6) {
            dynamicIslandStatusIcon(context: context)

            Text(shortDistanceText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    private var shortDistanceText: String {
        String(format: "%.1f", context.state.distanceMeters / 1000)
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct RunCompactTrailingView: View {
    let context: ActivityViewContext<RunLiveActivityAttributes>

    var body: some View {
        Group {
            if let countdownEndDate = countdownEndDate(for: context), isCountdownActive(for: context) {
                Text(timerInterval: Date()...countdownEndDate, countsDown: true)
            } else {
                Text(formattedDuration(for: context))
            }
        }
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct RunPrimaryActionStyle: ButtonStyle {
    let tint: Color
    let isCompact: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isCompact ? 12 : 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 36 : 42)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.84 : 1.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

@available(iOSApplicationExtension 17.0, *)
private extension View {
    func runPrimaryActionStyle(tint: Color, compact: Bool = false) -> some View {
        buttonStyle(RunPrimaryActionStyle(tint: tint, isCompact: compact))
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct RunLiveActivityActionButtons: View {
    let context: ActivityViewContext<RunLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 10) {
            if isCountdownActive(for: context) {
                Label("3초 후 재개", systemImage: "timer")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
            } else {
                pauseResumeButton()

                Button(intent: StopRunIntent(runID: context.attributes.runID)) {
                    Label("Finish", systemImage: "stop.fill")
                }
                .runPrimaryActionStyle(tint: RunActivityPalette.destructive)

                if context.state.status == .paused {
                    Button(intent: CancelRunIntent(runID: context.attributes.runID)) {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .runPrimaryActionStyle(tint: Color.white.opacity(0.14))
                }
            }
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct RunDynamicIslandActionButtons: View {
    let context: ActivityViewContext<RunLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 8) {
            if isCountdownActive(for: context) {
                Label("재개 중", systemImage: "timer")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
            } else {
                pauseResumeButton()

                Button(intent: StopRunIntent(runID: context.attributes.runID)) {
                    Label("Finish", systemImage: "stop.fill")
                }
                .runPrimaryActionStyle(tint: RunActivityPalette.destructive, compact: true)

                if context.state.status == .paused {
                    Button(intent: CancelRunIntent(runID: context.attributes.runID)) {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .runPrimaryActionStyle(tint: Color.white.opacity(0.14), compact: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOSApplicationExtension 17.0, *)
private extension RunLiveActivityActionButtons {
    @ViewBuilder
    func pauseResumeButton() -> some View {
        if context.state.status == .paused {
            Button(intent: ResumeRunIntent(runID: context.attributes.runID)) {
                Label("Resume", systemImage: "play.fill")
            }
            .runPrimaryActionStyle(tint: RunActivityPalette.accent)
        } else {
            Button(intent: PauseRunIntent(runID: context.attributes.runID)) {
                Label("Pause", systemImage: "pause.fill")
            }
            .runPrimaryActionStyle(tint: RunActivityPalette.accent)
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
private extension RunDynamicIslandActionButtons {
    @ViewBuilder
    func pauseResumeButton() -> some View {
        if context.state.status == .paused {
            Button(intent: ResumeRunIntent(runID: context.attributes.runID)) {
                Label("Resume", systemImage: "play.fill")
            }
            .runPrimaryActionStyle(tint: RunActivityPalette.accent, compact: true)
        } else {
            Button(intent: PauseRunIntent(runID: context.attributes.runID)) {
                Label("Pause", systemImage: "pause.fill")
            }
            .runPrimaryActionStyle(tint: RunActivityPalette.accent, compact: true)
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
#Preview("Lock Screen", as: .content, using: RunLiveActivityAttributes(runID: "preview-run", title: "러닝")) {
    RunLiveActivityWidget()
} contentStates: {
    RunLiveActivityAttributes.ContentState(
        elapsedSeconds: 1830,
        distanceMeters: 5280,
        paceText: "5'48\"",
        status: .running,
        countdownEndDate: nil
    )
}

@available(iOSApplicationExtension 17.0, *)
#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: RunLiveActivityAttributes(runID: "preview-run", title: "러닝")) {
    RunLiveActivityWidget()
} contentStates: {
    RunLiveActivityAttributes.ContentState(
        elapsedSeconds: 1830,
        distanceMeters: 5280,
        paceText: "5'48\"",
        status: .running,
        countdownEndDate: nil
    )
}

@available(iOSApplicationExtension 17.0, *)
#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: RunLiveActivityAttributes(runID: "preview-run", title: "러닝")) {
    RunLiveActivityWidget()
} contentStates: {
    RunLiveActivityAttributes.ContentState(
        elapsedSeconds: 1830,
        distanceMeters: 5280,
        paceText: "5'48\"",
        status: .running,
        countdownEndDate: nil
    )
}
