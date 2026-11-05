import SwiftUI

/// A Live Activity pushed by another app, script or shortcut. Observable, so
/// its island views update in place on every `update`.
@MainActor
@Observable
final class LiveActivity: IslandActivity {
    private(set) var state: LiveActivityState
    private(set) var isStale = false

    @ObservationIgnored var onHide: (() -> Void)?
    @ObservationIgnored var onOpenAction: ((URL) -> Void)?

    init(state: LiveActivityState) {
        self.state = state
    }

    func update(_ state: LiveActivityState, now: Date) {
        self.state = state
        isStale = state.isStale(now: now)
    }

    func refreshStaleness(now: Date) {
        let stale = state.isStale(now: now)
        if stale != isStale { isStale = stale }
    }

    // MARK: IslandActivity

    var id: String { state.id }
    var kind: ActivityKind { .liveActivity }
    var startedAt: Date { state.startedAt }

    var accessibilityLabel: String {
        var parts = [state.title]
        switch state.phase {
        case .ended(let result, let text, _):
            parts.append(text ?? result.title)
        case .running:
            if isStale { parts.append("No updates") }
            if case .value(let value) = state.progress { parts.append("\(Int((value * 100).rounded())) percent") }
            if let status = state.status { parts.append(status) }
        }
        return parts.joined(separator: ", ")
    }

    var compactLeading: AnyView { AnyView(LiveActivitySymbol(symbol: state.symbol, size: 22)) }
    var compactTrailing: AnyView { AnyView(LiveActivityIndicator(activity: self)) }
    var minimal: AnyView { AnyView(LiveActivitySymbol(symbol: state.symbol, size: 22)) }
    var expandedSource: AnyView { AnyView(Text(state.source)) }
    var expandedStatus: AnyView { AnyView(LiveActivityHeaderStatus(activity: self)) }
    var expandedContent: AnyView { AnyView(LiveActivityCard(activity: self)) }
}

extension LiveActivityResult {
    var title: String {
        switch self {
        case .success: "Done"
        case .failure: "Failed"
        case .cancelled: "Cancelled"
        }
    }
}
