import AppKit
import os

/// Applies Live Activity commands – from the URL scheme now, App Intents in
/// #12 – and keeps the activities in the island store: shows results for 3 s,
/// removes ended activities and marks stale ones.
@MainActor
final class LiveActivityManager {
    private(set) var activities: [String: LiveActivity] = [:]

    private let store: IslandStore
    private let now: () -> Date
    private let openURL: (URL) -> Void
    private var deadlineTask: Task<Void, Never>?

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "LiveActivity")

    init(
        store: IslandStore,
        now: @escaping () -> Date = Date.init,
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.store = store
        self.now = now
        self.openURL = openURL
    }

    func handle(_ command: LiveActivityCommand) {
        let time = now()
        switch command {
        case .start(let id, let fields):
            if let existing = activities[id] {
                var state = existing.state
                state.restart(fields, now: time)
                existing.update(state, now: time)
                store.upsert(existing) // new start time
            } else {
                let activity = LiveActivity(state: LiveActivityState(id: id, fields: fields, now: time))
                activity.onHide = { [weak self] in self?.hide(id: id) }
                activity.onOpenAction = { [weak self] url in self?.open(url) }
                activities[id] = activity
                store.upsert(activity)
            }
            Self.logger.info("Started '\(id, privacy: .public)'")

        case .update(let id, let fields):
            guard let activity = activities[id] else {
                Self.logger.error("Update for unknown activity '\(id, privacy: .public)' ignored")
                return
            }
            var state = activity.state
            guard state.apply(fields, now: time) else {
                Self.logger.error("Update for ended activity '\(id, privacy: .public)' ignored")
                return
            }
            activity.update(state, now: time)

        case .end(let id, let result, let text):
            guard let activity = activities[id] else {
                Self.logger.error("End for unknown activity '\(id, privacy: .public)' ignored")
                return
            }
            var state = activity.state
            state.end(result, text: text, now: time)
            activity.update(state, now: time)
            Self.logger.info("Ended '\(id, privacy: .public)': \(result.rawValue, privacy: .public)")
        }
        tick()
    }

    /// The user dismissed the activity ("Hide").
    func hide(id: String) {
        guard activities.removeValue(forKey: id) != nil else { return }
        store.remove(id: id)
        Self.logger.info("Hidden '\(id, privacy: .public)'")
        tick()
    }

    /// Removes ended activities whose result has been shown, marks stale
    /// ones, and schedules the next check.
    func tick() {
        let time = now()
        for (id, activity) in activities {
            let isExpanded = store.display == .expanded(id)
            if activity.state.shouldRemove(now: time, isExpanded: isExpanded) {
                activities[id] = nil
                store.remove(id: id)
            } else {
                activity.refreshStaleness(now: time)
            }
        }
        schedule(after: time)
    }

    private func open(_ url: URL) {
        openURL(url)
        store.collapse()
    }

    private func schedule(after time: Date) {
        deadlineTask?.cancel()
        let next = activities.values.compactMap { $0.state.nextDeadline(now: time) }.min()
        guard let next else { return }
        let delay = max(next.timeIntervalSince(time), 0.05)
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.tick()
        }
    }
}
