import SwiftUI

/// A short event (charging, low battery, Bluetooth) shown in compact form for
/// 2–4 s before the island returns to its previous state.
@MainActor
struct IslandEvent: Identifiable {
    let id: String
    let kind: EventKind
    let duration: Duration
    let accessibilityLabel: String
    let compactLeading: AnyView
    let compactTrailing: AnyView

    init(
        id: String = UUID().uuidString,
        kind: EventKind,
        duration: Duration? = nil,
        accessibilityLabel: String,
        compactLeading: AnyView,
        compactTrailing: AnyView
    ) {
        self.id = id
        self.kind = kind
        self.duration = duration ?? kind.defaultDuration
        self.accessibilityLabel = accessibilityLabel
        self.compactLeading = compactLeading
        self.compactTrailing = compactTrailing
    }

    var entry: EventEntry {
        EventEntry(id: id, kind: kind, duration: duration)
    }
}

/// The parts of an event the state machine needs.
struct EventEntry: Equatable, Sendable {
    let id: String
    let kind: EventKind
    let duration: Duration
}
