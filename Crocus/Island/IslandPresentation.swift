/// What the island currently shows. Provisional until the state machine
/// (#7) adds the minimal state and drives transitions from activities.
enum IslandPresentation: String, Equatable, Sendable {
    case idle
    case compact
    case expanded
}
