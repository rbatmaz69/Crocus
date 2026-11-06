import SwiftUI

/// The built-in timer or stopwatch in the island. Observable, so its views
/// update when it is paused, resumed or finishes; the ticking itself happens
/// in the views (`TimelineView`), not here.
@MainActor
@Observable
final class TimerActivity: IslandActivity {
    private(set) var state: TimerState
    /// Bumped on every finish; drives the `.bounce` symbol effect.
    private(set) var finishCount = 0
    /// The user has seen the finished timer expanded.
    @ObservationIgnored var wasSeenExpanded = false

    @ObservationIgnored var onPause: (() -> Void)?
    @ObservationIgnored var onResume: (() -> Void)?
    @ObservationIgnored var onStop: (() -> Void)?
    @ObservationIgnored var onRestart: (() -> Void)?
    @ObservationIgnored var onAddMinute: (() -> Void)?

    init(state: TimerState) {
        self.state = state
    }

    func update(_ state: TimerState) {
        if !state.isFinished { wasSeenExpanded = false }
        self.state = state
    }

    func didFinish() {
        finishCount += 1
    }

    // MARK: IslandActivity

    var id: String { TimerManager.id(for: state.kind) }
    var kind: ActivityKind { .timer }
    var startedAt: Date { state.startedAt }
    var accessibilityLabel: String { TimerFormat.accessibilityLabel(state, now: Date()) }

    var compactLeading: AnyView { AnyView(TimerSymbol(activity: self)) }
    var compactTrailing: AnyView { AnyView(TimerCompactReadout(activity: self)) }
    var compactTrailingReduced: AnyView { AnyView(TimerReducedIndicator(activity: self)) }
    var minimal: AnyView { AnyView(TimerSymbol(activity: self)) }
    var expandedSource: AnyView { AnyView(Text(TimerFormat.title(state.kind))) }
    var expandedStatus: AnyView { AnyView(Text(TimerFormat.status(state))) }
    var expandedContent: AnyView { AnyView(TimerCard(activity: self)) }
}
