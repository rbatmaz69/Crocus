import Foundation

/// What the island shows right now.
enum IslandDisplay: Equatable, Sendable {
    case idle
    /// One activity.
    case compact(primary: String)
    /// Two or more: the main shape shows the highest priority, the drop
    /// (#9) the second.
    case minimal(primary: String, secondary: String)
    case expanded(String)
    /// An event overlays the island in compact form.
    case event(String)

    var presentation: IslandPresentation {
        switch self {
        case .idle: .idle
        case .compact, .event: .compact
        case .minimal: .minimal
        case .expanded: .expanded
        }
    }
}

/// The island's state machine (board 00), as a pure value: the caller passes
/// the time, so every transition is deterministic and testable.
///
/// Idle → activity starts → compact → 2nd activity → minimal.
/// Compact/minimal → expand → expanded → collapse → back.
/// Events overlay idle/compact/minimal for their duration and then return;
/// while expanded they wait and show right after collapsing if they are at
/// most 5 s old.
struct IslandState: Sendable {
    typealias Instant = ContinuousClock.Instant

    /// Events waiting longer than this (e.g. while expanded) are dropped.
    static let pendingEventMaxAge: Duration = .seconds(5)

    struct RunningEvent: Equatable, Sendable {
        let entry: EventEntry
        let endsAt: Instant
    }

    struct PendingEvent: Equatable, Sendable {
        let entry: EventEntry
        let receivedAt: Instant
    }

    private(set) var priority: ActivityPriority
    /// Highest priority first.
    private(set) var activities: [ActivityEntry] = []
    private(set) var expandedActivityID: String?
    private(set) var currentEvent: RunningEvent?
    private(set) var pendingEvents: [PendingEvent] = []

    init(priority: ActivityPriority = .default) {
        self.priority = priority
    }

    // MARK: - Derived

    /// The state without expansion or events.
    var base: IslandDisplay {
        switch activities.count {
        case 0: .idle
        case 1: .compact(primary: activities[0].id)
        default: .minimal(primary: activities[0].id, secondary: activities[1].id)
        }
    }

    var display: IslandDisplay {
        if let expandedActivityID { return .expanded(expandedActivityID) }
        if let currentEvent { return .event(currentEvent.entry.id) }
        return base
    }

    /// When `tick` has to run next (the running event ends).
    var nextDeadline: Instant? { currentEvent?.endsAt }

    // MARK: - Activities

    mutating func upsert(_ entry: ActivityEntry) {
        if let index = activities.firstIndex(where: { $0.id == entry.id }) {
            activities[index] = entry
        } else {
            activities.append(entry)
        }
        activities = priority.sorted(activities)
    }

    mutating func remove(id: String, now: Instant) {
        activities.removeAll { $0.id == id }
        if expandedActivityID == id {
            collapse(now: now)
        }
    }

    mutating func setPriority(_ priority: ActivityPriority) {
        self.priority = priority
        activities = priority.sorted(activities)
    }

    // MARK: - Expand / collapse

    /// Expands the given activity (e.g. the drop's), or the main one. Only
    /// from compact or minimal; ignored while idle or already expanded.
    @discardableResult
    mutating func expand(id: String? = nil) -> Bool {
        guard expandedActivityID == nil, let primary = activities.first else { return false }
        let target = id ?? primary.id
        guard activities.contains(where: { $0.id == target }) else { return false }
        expandedActivityID = target
        // The running event has been seen; it ends when the user expands.
        currentEvent = nil
        return true
    }

    @discardableResult
    mutating func collapse(now: Instant) -> Bool {
        guard expandedActivityID != nil else { return false }
        expandedActivityID = nil
        startNextEvent(now: now)
        return true
    }

    // MARK: - Cards

    /// While expanded, moves to the next activity in priority order (stops at
    /// the end; the rubber band comes with #23).
    @discardableResult
    mutating func showNextCard() -> Bool { moveCard(by: 1) }

    @discardableResult
    mutating func showPreviousCard() -> Bool { moveCard(by: -1) }

    private mutating func moveCard(by offset: Int) -> Bool {
        guard let expandedActivityID,
              let index = activities.firstIndex(where: { $0.id == expandedActivityID }),
              activities.indices.contains(index + offset)
        else { return false }
        self.expandedActivityID = activities[index + offset].id
        return true
    }

    // MARK: - Events

    mutating func post(_ event: EventEntry, now: Instant) {
        // A newer event of the same kind replaces the older one.
        pendingEvents.removeAll { $0.entry.kind == event.kind }
        if let running = currentEvent, running.entry.kind == event.kind {
            currentEvent = RunningEvent(entry: event, endsAt: now + event.duration)
            return
        }
        pendingEvents.append(PendingEvent(entry: event, receivedAt: now))
        startNextEvent(now: now)
    }

    /// Ends the running event once its time is up and starts the next one.
    mutating func tick(now: Instant) {
        if let running = currentEvent, now >= running.endsAt {
            currentEvent = nil
        }
        startNextEvent(now: now)
    }

    private mutating func startNextEvent(now: Instant) {
        guard expandedActivityID == nil, currentEvent == nil else { return }
        pendingEvents.removeAll { now - $0.receivedAt > Self.pendingEventMaxAge }
        guard !pendingEvents.isEmpty else { return }
        let next = pendingEvents.removeFirst()
        currentEvent = RunningEvent(entry: next.entry, endsAt: now + next.entry.duration)
    }
}
