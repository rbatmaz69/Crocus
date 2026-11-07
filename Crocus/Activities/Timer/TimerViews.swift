import SwiftUI

/// Redraws its content once per shown second while the timer runs; static
/// while paused or finished.
struct TimerTicking<Content: View>: View {
    let state: TimerState
    @ViewBuilder var content: (Date) -> Content

    var body: some View {
        if let anchor = state.tickAnchor {
            TimelineView(.periodic(from: anchor, by: 1)) { context in
                content(context.date)
            }
        } else {
            content(Date())
        }
    }
}

/// `timer` / `stopwatch` symbol; bounces when the timer finishes – not with
/// Reduce Motion (the haptic and the finished state still tell).
struct TimerSymbol: View {
    let activity: TimerActivity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        IslandCompactSymbol(systemName: TimerFormat.symbol(activity.state.kind))
            .symbolEffect(.bounce, options: .repeat(3), value: Self.bounceTrigger(finishCount: activity.finishCount, reduceMotion: reduceMotion))
    }

    /// Changes – and so bounces the symbol – each time the timer finishes.
    static func bounceTrigger(finishCount: Int, reduceMotion: Bool) -> Int {
        reduceMotion ? 0 : finishCount
    }
}

/// Right wing: "04:32" (Semibold 15, tabular digits); dimmed while paused.
struct TimerCompactReadout: View {
    let activity: TimerActivity

    var body: some View {
        let state = activity.state
        TimerTicking(state: state) { date in
            IslandCompactValue(
                text: TimerFormat.readout(state, now: date),
                dimmed: state.isPaused
            )
        }
    }
}

/// Right wing reduced to 44 pt: remaining time as a ring (timer), or the
/// seconds hand as a ring (stopwatch).
struct TimerReducedIndicator: View {
    let activity: TimerActivity

    var body: some View {
        let state = activity.state
        TimerTicking(state: state) { date in
            let progress = state.remainingFraction(now: date)
                ?? state.elapsed(now: date).truncatingRemainder(dividingBy: 60) / 60
            IslandProgressRing(progress: progress, tint: state.isPaused ? CrocusColors.secondary : CrocusColors.progress)
        }
    }
}

/// Expanded: the time (Display Light 44), subtitle, Pause / Stop as 44 pt
/// circles, and the remaining time as a blue bar. Once finished: Restart,
/// +1 Min and Stop.
struct TimerCard: View {
    let activity: TimerActivity

    var body: some View {
        let state = activity.state
        TimerTicking(state: state) { date in
            VStack(alignment: .leading, spacing: CrocusMetrics.Expanded.rowSpacing) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TimerFormat.readout(state, now: date))
                            .islandFont(CrocusTypography.display)
                            .foregroundStyle(state.isPaused ? AnyShapeStyle(IslandSecondaryStyle()) : AnyShapeStyle(CrocusColors.primary))
                            .lineLimit(1)
                        Text(TimerFormat.subtitle(state, now: date))
                            .islandFont(CrocusTypography.status)
                            .foregroundStyle(.islandSecondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(TimerFormat.accessibilityLabel(state, now: date))
                    Spacer(minLength: 8)
                    controls(state)
                }
                if let fraction = state.remainingFraction(now: date) {
                    IslandProgressBar(progress: fraction, height: 4)
                        .accessibilityHidden(true)
                }
                if state.isFinished {
                    HStack(spacing: 8) {
                        IslandButton(title: "Restart", primary: true) { activity.onRestart?() }
                        IslandButton(title: "+1 Min") { activity.onAddMinute?() }
                    }
                }
            }
            .foregroundStyle(CrocusColors.primary)
        }
    }

    @ViewBuilder
    private func controls(_ state: TimerState) -> some View {
        HStack(spacing: 10) {
            switch state.phase {
            case .running:
                IslandCircleButton(systemName: "pause.fill", accessibilityLabel: "Pause") { activity.onPause?() }
            case .paused:
                IslandCircleButton(systemName: "play.fill", accessibilityLabel: "Resume") { activity.onResume?() }
            case .finished:
                EmptyView()
            }
            IslandCircleButton(systemName: "xmark", accessibilityLabel: "Stop") { activity.onStop?() }
        }
    }
}
