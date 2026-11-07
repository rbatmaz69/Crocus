import Foundation
import os

/// The single place all activity sources push into. Holds the activity and
/// event objects, runs the `IslandState` machine and its event timer, and
/// tells the overlay what to show.
@MainActor
@Observable
final class IslandStore {
    private(set) var state: IslandState
    private(set) var activities: [String: any IslandActivity] = [:]
    private(set) var events: [String: IslandEvent] = [:]

    /// The activity last shown expanded / in the compact main shape. Kept
    /// after the state moves on, so content fading out during a transition
    /// keeps showing what was there instead of the next activity.
    private(set) var lastExpandedID: String?
    private(set) var lastCompactID: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> ContinuousClock.Instant
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?
    @ObservationIgnored private var scheduledDeadline: ContinuousClock.Instant?
    @ObservationIgnored private var defaultsObserver: NSObjectProtocol?

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Island")

    init(defaults: UserDefaults = .standard, now: @escaping () -> ContinuousClock.Instant = { .now }) {
        self.defaults = defaults
        self.now = now
        self.state = IslandState(priority: AppSettings.activityPriority(in: defaults))
        self.disabledKinds = AppSettings.disabledActivities(in: defaults)
        self.disabledEvents = AppSettings.disabledEvents(in: defaults)
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadSettings() }
        }
    }

    // MARK: - What to show

    var display: IslandDisplay { state.display }
    var presentation: IslandPresentation { state.display.presentation }

    /// The activity in the main shape (compact/minimal) or the expanded one.
    var primaryActivity: (any IslandActivity)? {
        switch state.display {
        case .compact(let id), .minimal(let id, _), .expanded(let id): activities[id]
        case .idle, .event: nil
        }
    }

    /// The activity in the drop/circle (#9).
    var secondaryActivity: (any IslandActivity)? {
        if case .minimal(_, let id) = state.display { return activities[id] }
        return nil
    }

    var currentEvent: IslandEvent? {
        if case .event(let id) = state.display { return events[id] }
        return nil
    }

    /// Content for the expanded layout: the expanded activity, or – while
    /// collapsing – the one that was expanded.
    var expandedContentActivity: (any IslandActivity)? {
        lastExpandedID.flatMap { activities[$0] }
    }

    /// Content for the compact layout's main shape: the current main
    /// activity, or – while expanding or fading to idle – the last one.
    var compactContentActivity: (any IslandActivity)? {
        lastCompactID.flatMap { activities[$0] }
    }

    var accessibilityLabel: String {
        currentEvent?.accessibilityLabel ?? primaryActivity?.accessibilityLabel ?? ""
    }

    // MARK: - Sources

    /// Types switched off in Settings: their activities are kept (so they
    /// are back at once when switched on again) but not shown.
    private(set) var disabledKinds: Set<ActivityKind>
    /// Events switched off in Settings are dropped.
    private(set) var disabledEvents: Set<EventKind>

    func upsert(_ activity: any IslandActivity) {
        activities[activity.id] = activity
        guard !disabledKinds.contains(activity.kind) else { return }
        update { $0.upsert(activity.entry) }
    }

    func remove(id: String) {
        guard activities[id] != nil else { return }
        activities[id] = nil
        let time = now()
        update { $0.remove(id: id, now: time) }
    }

    func removeAll() {
        for id in activities.keys { remove(id: id) }
    }

    func post(_ event: IslandEvent) {
        guard !disabledEvents.contains(event.kind) else { return }
        events[event.id] = event
        let time = now()
        update { $0.post(event.entry, now: time) }
    }

    // MARK: - Interaction (#8)

    func expand(id: String? = nil) {
        update { $0.expand(id: id) }
    }

    func collapse() {
        let time = now()
        update { $0.collapse(now: time) }
    }

    /// Global shortcut: collapse when expanded, expand otherwise.
    func toggle() {
        if presentation == .expanded { collapse() } else { expand() }
    }

    func showCard(at index: Int) {
        update { $0.showCard(at: index) }
    }

    /// Position of the card shown in the expanded layout and the number of
    /// cards. Follows the last expanded activity, so it stays put while the
    /// island collapses.
    var cardPosition: (index: Int, count: Int)? {
        guard let id = lastExpandedID,
              let index = state.activities.firstIndex(where: { $0.id == id })
        else { return nil }
        return (index, state.activities.count)
    }

    /// All cards in priority order (C4: the strip the cards slide on).
    var cardActivities: [any IslandActivity] {
        state.activities.compactMap { activities[$0.id] }
    }

    func showNextCard() {
        update { $0.showNextCard() }
    }

    func showPreviousCard() {
        update { $0.showPreviousCard() }
    }

    // MARK: - Internals

    private func reloadSettings() {
        let priority = AppSettings.activityPriority(in: defaults)
        if priority != state.priority {
            update { $0.setPriority(priority) }
        }
        disabledEvents = AppSettings.disabledEvents(in: defaults)
        let disabled = AppSettings.disabledActivities(in: defaults)
        guard disabled != disabledKinds else { return }
        let switchedOff = disabled.subtracting(disabledKinds)
        let switchedOn = disabledKinds.subtracting(disabled)
        disabledKinds = disabled
        let time = now()
        for activity in activities.values {
            if switchedOff.contains(activity.kind) {
                update { $0.remove(id: activity.id, now: time) }
            } else if switchedOn.contains(activity.kind) {
                update { $0.upsert(activity.entry) }
            }
        }
    }

    private func update(_ change: (inout IslandState) -> Void) {
        let before = state.display
        change(&state)
        pruneEvents()
        switch state.display {
        case .expanded(let id): lastExpandedID = id
        case .compact(let id), .minimal(let id, _): lastCompactID = id
        case .idle, .event: break
        }
        if state.display != before {
            Self.logger.info("Island: \(String(describing: before), privacy: .public) → \(String(describing: self.state.display), privacy: .public)")
        }
        scheduleDeadline()
    }

    /// Drops event objects the state machine no longer knows about.
    private func pruneEvents() {
        var known = Set(state.pendingEvents.map(\.entry.id))
        if let running = state.currentEvent { known.insert(running.entry.id) }
        events = events.filter { known.contains($0.key) }
    }

    private func scheduleDeadline() {
        let deadline = state.nextDeadline
        guard deadline != scheduledDeadline else { return }
        scheduledDeadline = deadline
        deadlineTask?.cancel()
        guard let deadline else { return }

        deadlineTask = Task { [weak self] in
            // Tight tolerance: events end on time (storyboard C6: 2500 ms).
            try? await Task.sleep(until: deadline, tolerance: .milliseconds(10), clock: .continuous)
            guard !Task.isCancelled, let self else { return }
            self.scheduledDeadline = nil
            let time = self.now()
            self.update { $0.tick(now: time) }
        }
    }
}
