import AppKit
import SwiftUI
import os

/// Runs the built-in timer and stopwatch: one of each at a time. Keeps them
/// in the island store, saves them so they survive a relaunch, and announces
/// a finished timer with a sound, a symbol bounce and VoiceOver.
@MainActor
@Observable
final class TimerManager {
    /// What happens when a timer finishes; injectable for tests.
    struct FinishEffects {
        var finished: @MainActor (TimerState) -> Void

        static let system = FinishEffects { _ in
            NSSound(named: "Glass")?.play()
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            AccessibilityNotification.Announcement("Timer finished").post()
        }
    }

    private(set) var timers: [TimerState.Kind: TimerActivity] = [:]

    @ObservationIgnored private let store: IslandStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let effects: FinishEffects
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Timer")

    static func id(for kind: TimerState.Kind) -> String { "timer.\(kind.rawValue)" }

    init(
        store: IslandStore,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        effects: FinishEffects = .system
    ) {
        self.store = store
        self.defaults = defaults
        self.now = now
        self.effects = effects
    }

    /// Restores saved timers and re-checks them after the Mac wakes up.
    func start() {
        restore()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func state(_ kind: TimerState.Kind) -> TimerState? { timers[kind]?.state }

    // MARK: - Commands

    /// Starts a timer; replaces a timer that is already there.
    func startTimer(duration: TimeInterval) {
        set(.timer(duration: duration, now: now()))
        Self.logger.info("Started timer: \(Int(duration), privacy: .public) s")
    }

    /// Starts the stopwatch from zero; replaces a running one.
    func startStopwatch() {
        set(.stopwatch(now: now()))
        Self.logger.info("Started stopwatch")
    }

    func pause(_ kind: TimerState.Kind) {
        change(kind) { $0.pause(now: now()) }
    }

    func resume(_ kind: TimerState.Kind) {
        change(kind) { $0.resume(now: now()) }
    }

    func stop(_ kind: TimerState.Kind) {
        guard timers.removeValue(forKey: kind) != nil else { return }
        store.remove(id: Self.id(for: kind))
        Self.logger.info("Stopped \(kind.rawValue, privacy: .public)")
        save()
        tick()
    }

    /// A finished timer again with the same duration.
    func restart(_ kind: TimerState.Kind) {
        guard let state = timers[kind]?.state else { return }
        switch kind {
        case .timer: startTimer(duration: state.duration ?? 60)
        case .stopwatch: startStopwatch()
        }
    }

    /// A finished timer for one more minute.
    func addMinute() {
        startTimer(duration: 60)
    }

    // MARK: - Lifecycle

    /// Finishes timers that reached zero, removes finished ones that were
    /// shown long enough, and schedules the next check.
    func tick() {
        let time = now()
        var changed = false
        for (kind, activity) in timers {
            var state = activity.state
            if state.finishIfDue(now: time) {
                activity.update(state)
                activity.didFinish()
                effects.finished(state)
                Self.logger.info("Timer finished")
                changed = true
            }
            let isExpanded = store.display == .expanded(activity.id)
            if isExpanded, state.isFinished { activity.wasSeenExpanded = true }
            if state.shouldRemove(now: time, wasSeenExpanded: activity.wasSeenExpanded, isExpanded: isExpanded) {
                timers[kind] = nil
                store.remove(id: activity.id)
                changed = true
            }
        }
        if changed { save() }
        schedule(after: time)
    }

    // MARK: - Internals

    private func set(_ state: TimerState) {
        if let activity = timers[state.kind] {
            activity.update(state)
            store.upsert(activity) // new start time
        } else {
            let activity = TimerActivity(state: state)
            let kind = state.kind
            activity.onPause = { [weak self] in self?.pause(kind) }
            activity.onResume = { [weak self] in self?.resume(kind) }
            activity.onStop = { [weak self] in self?.stop(kind) }
            activity.onRestart = { [weak self] in self?.restart(kind) }
            activity.onAddMinute = { [weak self] in self?.addMinute() }
            timers[kind] = activity
            store.upsert(activity)
        }
        save()
        tick()
    }

    private func change(_ kind: TimerState.Kind, _ change: (inout TimerState) -> Void) {
        guard let activity = timers[kind] else { return }
        var state = activity.state
        change(&state)
        guard state != activity.state else { return }
        activity.update(state)
        Self.logger.info("\(kind.rawValue, privacy: .public): \(TimerFormat.status(state), privacy: .public)")
        save()
        tick()
    }

    private func schedule(after time: Date) {
        deadlineTask?.cancel()
        let next = timers.values.compactMap { $0.state.nextDeadline(now: time) }.min()
        guard let next else { return }
        let delay = max(next.timeIntervalSince(time), 0.05)
        deadlineTask = Task { [weak self] in
            // Tight tolerance: the sound should come with "00:00", not later.
            try? await Task.sleep(for: .seconds(delay), tolerance: .milliseconds(10))
            guard !Task.isCancelled else { return }
            self?.tick()
        }
    }

    // MARK: - Persistence

    private func save() {
        let states = timers.values.map(\.state).sorted { $0.kind.rawValue < $1.kind.rawValue }
        if states.isEmpty {
            defaults.removeObject(forKey: AppSettings.Key.timers)
        } else if let data = try? JSONEncoder().encode(states) {
            defaults.set(data, forKey: AppSettings.Key.timers)
        }
    }

    private func restore() {
        guard let data = defaults.data(forKey: AppSettings.Key.timers),
              let saved = try? JSONDecoder().decode([TimerState].self, from: data)
        else { return }
        let time = now()
        for saved in saved {
            guard let state = saved.restored(now: time) else { continue }
            set(state)
            if state.isFinished, !saved.isFinished {
                // Ran out while Crocus wasn't running: announce it now.
                Self.logger.info("Timer finished while Crocus wasn't running")
                timers[state.kind]?.didFinish()
                effects.finished(state)
            }
        }
        Self.logger.info("Restored \(self.timers.count, privacy: .public) timer(s)")
        save()
    }
}
