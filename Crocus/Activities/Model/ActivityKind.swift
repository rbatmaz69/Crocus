/// The kinds of long-running activities, in their default priority order
/// (highest first). Camera/microphone is fixed on top for privacy; the rest
/// can be reordered in settings (#27).
enum ActivityKind: String, CaseIterable, Sendable {
    case cameraMicrophone
    case calendar
    case timer
    case liveActivity
    case download
    case music

    /// Always shown first, whatever the user's order.
    var isFixedOnTop: Bool { self == .cameraMicrophone }
}

/// Short events (2–4 s) that briefly overlay the island and then return to
/// the previous state. They have no priority slot.
enum EventKind: String, CaseIterable, Sendable {
    case charging
    case lowBattery
    case bluetooth

    var defaultDuration: Duration {
        switch self {
        case .charging: .milliseconds(2500)
        case .lowBattery: .seconds(4)
        case .bluetooth: .seconds(2)
        }
    }
}
