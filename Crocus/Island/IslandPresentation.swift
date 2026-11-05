/// The shape the island takes. Derived from `IslandDisplay` by the state
/// machine (#7).
enum IslandPresentation: String, Equatable, Sendable {
    case idle
    /// One activity, or an event.
    case compact
    /// Two or more activities: main shape plus drop/circle (drawn in #9;
    /// until then like compact).
    case minimal
    case expanded
}
