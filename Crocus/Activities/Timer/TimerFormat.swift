import Foundation

/// Texts for timers: the readout, the subtitle and what VoiceOver reads.
enum TimerFormat {
    /// "04:32", "1:04:32". Timers round up – "00:00" only once it ran out –
    /// stopwatches round down.
    static func clock(_ seconds: TimeInterval, roundingUp: Bool) -> String {
        let total = Int((roundingUp ? seconds.rounded(.up) : seconds.rounded(.down)).clamped(to: 0...Double(Int.max / 2)))
        let hours = total / 3600, minutes = total / 60 % 60, secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }

    static func readout(_ state: TimerState, now: Date) -> String {
        clock(state.displayedSeconds(now: now), roundingUp: state.kind == .timer)
    }

    /// "10:00" for a whole duration; "1:30:00" with hours.
    static func duration(_ seconds: TimeInterval) -> String {
        clock(seconds, roundingUp: true)
    }

    /// "Timer · 10:00 · ends 14:37", "Timer · 10:00 · paused",
    /// "Timer · 10:00 · ended 14:37", "Stopwatch · since 14:12".
    static func subtitle(_ state: TimerState, now: Date, timeStyle: (Date) -> String = time) -> String {
        switch state.kind {
        case .stopwatch:
            return "Stopwatch · since \(timeStyle(state.startedAt))"
        case .timer:
            let parts = "Timer · \(duration(state.duration ?? 0))"
            switch state.phase {
            case .running: return "\(parts) · ends \(timeStyle(state.endDate ?? now))"
            case .paused: return "\(parts) · paused"
            case .finished(let at): return "\(parts) · ended \(timeStyle(at))"
            }
        }
    }

    /// "Running", "Paused", "Done".
    static func status(_ state: TimerState) -> String {
        switch state.phase {
        case .running: "Running"
        case .paused: "Paused"
        case .finished: "Done"
        }
    }

    static func title(_ kind: TimerState.Kind) -> String {
        switch kind {
        case .timer: "Timer"
        case .stopwatch: "Stopwatch"
        }
    }

    static func symbol(_ kind: TimerState.Kind) -> String {
        switch kind {
        case .timer: "timer"
        case .stopwatch: "stopwatch"
        }
    }

    /// "Timer, 4 minutes 32 seconds remaining", "Timer paused, …",
    /// "Timer finished", "Stopwatch, 1 minute 5 seconds".
    static func accessibilityLabel(_ state: TimerState, now: Date) -> String {
        let spoken = spokenDuration(state.displayedSeconds(now: now), roundingUp: state.kind == .timer)
        switch (state.kind, state.phase) {
        case (.timer, .finished): return "Timer finished"
        case (.timer, .paused): return "Timer paused, \(spoken) remaining"
        case (.timer, _): return "Timer, \(spoken) remaining"
        case (.stopwatch, .paused): return "Stopwatch paused, \(spoken)"
        case (.stopwatch, _): return "Stopwatch, \(spoken)"
        }
    }

    /// "4 minutes 32 seconds", "1 hour 2 minutes", "0 seconds".
    static func spokenDuration(_ seconds: TimeInterval, roundingUp: Bool) -> String {
        let total = Int((roundingUp ? seconds.rounded(.up) : seconds.rounded(.down)).clamped(to: 0...Double(Int.max / 2)))
        let units = [(total / 3600, "hour"), (total / 60 % 60, "minute"), (total % 60, "second")]
        let parts = units.filter { $0.0 > 0 }.map { "\($0.0) \($0.1)\($0.0 == 1 ? "" : "s")" }
        return parts.isEmpty ? "0 seconds" : parts.joined(separator: " ")
    }

    /// Clock time in the user's format, e.g. "14:37".
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
