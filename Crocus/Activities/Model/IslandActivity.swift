import SwiftUI

/// A long-running activity shown in the island. Activity sources (#13–#19,
/// Live Activities #11) implement this and push themselves into the
/// `IslandStore`. Views are type-erased so the store can hold any source.
@MainActor
protocol IslandActivity: AnyObject {
    /// Stable identifier; pushing an activity with the same id updates it.
    var id: String { get }
    var kind: ActivityKind { get }
    /// When it started; breaks ties between activities of the same kind.
    var startedAt: Date { get }
    /// What VoiceOver reads for the compact island, e.g. "Timer, 4 minutes
    /// 32 seconds remaining".
    var accessibilityLabel: String { get }
    /// Short name for VoiceOver where the activities are listed (page dots:
    /// "Activity 2 of 3, Deploy"). Defaults to the kind's name.
    var accessibilityTitle: String { get }

    /// Symbol in the left wing.
    var compactLeading: AnyView { get }
    /// Value in the right wing.
    var compactTrailing: AnyView { get }
    /// Right wing content when it is reduced to 44 pt (symbol or ring only).
    var compactTrailingReduced: AnyView { get }

    /// Content of the drop/circle when this is the second activity
    /// (minimal state): cover, symbol or ring.
    var minimal: AnyView { get }

    /// Expanded header, left of the camera.
    var expandedSource: AnyView { get }
    /// Expanded header, right of the camera.
    var expandedStatus: AnyView { get }
    /// Expanded rows below the header.
    var expandedContent: AnyView { get }

    // Menu bar panel (#61): one row per activity under "Now".
    /// Symbol in the row's coloured tile.
    var panelSymbol: String { get }
    var panelTint: Color { get }
    var panelTitle: String { get }
    /// Second line, e.g. "04:32 remaining"; may tick.
    var panelDetail: AnyView { get }
    /// The activity's main controls on the right (pause, stop, progress …).
    var panelControls: AnyView { get }
}

extension IslandActivity {
    var accessibilityTitle: String { kind.title }
    var compactTrailingReduced: AnyView { compactTrailing }
    var minimal: AnyView { compactLeading }
    var panelSymbol: String { kind.panelSymbol }
    var panelTint: Color { kind.panelTint }
    var panelTitle: String { accessibilityTitle }
    var panelDetail: AnyView { AnyView(EmptyView()) }
    var panelControls: AnyView { AnyView(EmptyView()) }

    /// The value the state machine works with.
    var entry: ActivityEntry {
        ActivityEntry(id: id, kind: kind, startedAt: startedAt)
    }
}

/// The parts of an activity the state machine needs: identity, kind and age.
struct ActivityEntry: Equatable, Sendable {
    let id: String
    let kind: ActivityKind
    let startedAt: Date
}
