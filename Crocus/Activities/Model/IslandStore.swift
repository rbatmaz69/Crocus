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
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadPriority() }
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

    var accessibilityLabel: String {
        currentEvent?.accessibilityLabel ?? primaryActivity?.accessibilityLabel ?? ""
    }

    // MARK: - Sources

    func upsert(_ activity: any IslandActivity) {
        activities[activity.id] = activity
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

    func showNextCard() {
        update { $0.showNextCard() }
    }

    func showPreviousCard() {
        update { $0.showPreviousCard() }
    }

    // MARK: - Internals

    private func reloadPriority() {
        let priority = AppSettings.activityPriority(in: defaults)
        guard priority != state.priority else { return }
        update { $0.setPriority(priority) }
    }

    private func update(_ change: (inout IslandState) -> Void) {
        let before = state.display
        change(&state)
        pruneEvents()
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
            try? await Task.sleep(until: deadline, clock: .continuous)
            guard !Task.isCancelled, let self else { return }
            self.scheduledDeadline = nil
            let time = self.now()
            self.update { $0.tick(now: time) }
        }
    }
}
