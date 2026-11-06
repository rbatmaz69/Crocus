import Foundation

/// A timer (counts down) or stopwatch (counts up) as a pure value – time is
/// passed in. Only dates and accumulated time are stored, never a ticking
/// counter, so it stays right across sleep and relaunch.
struct TimerState: Codable, Equatable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable {
        case timer
        case stopwatch
    }

    enum Phase: Codable, Equatable, Sendable {
        /// Running since the date, on top of `accumulated`.
        case running(since: Date)
        case paused
        /// Timer only: reached zero at the date.
        case finished(at: Date)
    }

    /// Timers from 1 s to 24 h.
    static let durationRange: ClosedRange<TimeInterval> = 1...(24 * 60 * 60)
    /// A finished timer stays this long at most.
    static let finishedDisplayDuration: TimeInterval = 60

    let kind: Kind
    /// Timer only.
    private(set) var duration: TimeInterval?
    private(set) var startedAt: Date
    /// Time counted before the current run.
    private(set) var accumulated: TimeInterval = 0
    private(set) var phase: Phase

    static func timer(duration: TimeInterval, now: Date) -> TimerState {
        let duration = min(max(duration, durationRange.lowerBound), durationRange.upperBound)
        return TimerState(kind: .timer, duration: duration, startedAt: now, phase: .running(since: now))
    }

    static func stopwatch(now: Date) -> TimerState {
        TimerState(kind: .stopwatch, duration: nil, startedAt: now, phase: .running(since: now))
    }

    var isRunning: Bool { if case .running = phase { true } else { false } }
    var isPaused: Bool { phase == .paused }
    var isFinished: Bool { if case .finished = phase { true } else { false } }

    func elapsed(now: Date) -> TimeInterval {
        switch phase {
        case .running(let since): accumulated + max(now.timeIntervalSince(since), 0)
        case .paused: accumulated
        case .finished: duration ?? accumulated
        }
    }

    /// Timer only.
    func remaining(now: Date) -> TimeInterval? {
        duration.map { max($0 - elapsed(now: now), 0) }
    }

    /// Timer only: remaining time as a fraction, 1 → 0.
    func remainingFraction(now: Date) -> Double? {
        guard let duration, let remaining = remaining(now: now) else { return nil }
        return remaining / duration
    }

    /// When a running timer reaches zero.
    var endDate: Date? {
        guard case .running(let since) = phase, let duration else { return nil }
        return since.addingTimeInterval(duration - accumulated)
    }

    /// The value shown: remaining time (timer) or elapsed time (stopwatch).
    func displayedSeconds(now: Date) -> TimeInterval {
        remaining(now: now) ?? elapsed(now: now)
    }

    /// A date from which the shown whole seconds change every 1 s exactly,
    /// for the ticking views. `nil` unless running.
    var tickAnchor: Date? {
        guard case .running(let since) = phase else { return nil }
        if let duration {
            // The timer shows rounded-up seconds: they change at end − n.
            let left = duration - accumulated
            return since.addingTimeInterval(left - left.rounded(.up))
        }
        return since.addingTimeInterval(-accumulated.truncatingRemainder(dividingBy: 1))
    }

    mutating func pause(now: Date) {
        guard case .running(let since) = phase else { return }
        accumulated += max(now.timeIntervalSince(since), 0)
        if let duration { accumulated = min(accumulated, duration) }
        phase = .paused
    }

    mutating func resume(now: Date) {
        guard isPaused else { return }
        phase = .running(since: now)
    }

    /// Marks a running timer as finished once it reached zero. Returns
    /// whether it just finished.
    @discardableResult
    mutating func finishIfDue(now: Date) -> Bool {
        guard let endDate, now >= endDate, let duration else { return false }
        accumulated = duration
        phase = .finished(at: endDate)
        return true
    }

    /// A finished timer goes after 60 s, or once the user has looked at it
    /// expanded and the island collapsed again.
    func shouldRemove(now: Date, wasSeenExpanded: Bool, isExpanded: Bool) -> Bool {
        guard case .finished(let at) = phase else { return false }
        if now.timeIntervalSince(at) >= Self.finishedDisplayDuration { return true }
        return wasSeenExpanded && !isExpanded
    }

    /// When something changes next: the end of a running timer, or – while
    /// finished – the next check (every second) up to the 60 s limit.
    func nextDeadline(now: Date) -> Date? {
        switch phase {
        case .running: endDate
        case .paused: nil
        case .finished(let at): min(now.addingTimeInterval(1), at.addingTimeInterval(Self.finishedDisplayDuration))
        }
    }

    /// The state to continue with after a relaunch. A timer that ran out
    /// while Crocus wasn't running comes back finished if that was less than
    /// a minute ago (so it is still announced), otherwise it is dropped.
    func restored(now: Date) -> TimerState? {
        var state = self
        state.finishIfDue(now: now)
        if case .finished(let at) = state.phase, now.timeIntervalSince(at) >= Self.finishedDisplayDuration {
            return nil
        }
        return state
    }
}
