import CoreGraphics

/// Decides when the pointer has "settled" on another screen: only after it
/// stayed there for `delay` without interruption. Pure value type; the caller
/// passes the time, so it is fully testable.
struct PointerScreenDebounce: Sendable {
    typealias Instant = ContinuousClock.Instant

    let delay: Duration
    private(set) var settled: CGDirectDisplayID?
    private var candidate: (id: CGDirectDisplayID, since: Instant)?

    init(delay: Duration = .seconds(1), settled: CGDirectDisplayID? = nil) {
        self.delay = delay
        self.settled = settled
    }

    /// When the pending candidate would settle, if there is one.
    var deadline: Instant? { candidate.map { $0.since + delay } }

    var pendingScreen: CGDirectDisplayID? { candidate?.id }

    /// Feed the screen under the pointer. Returns the new settled screen when
    /// it changes, otherwise `nil`.
    mutating func observe(_ screen: CGDirectDisplayID?, at now: Instant) -> CGDirectDisplayID? {
        guard let screen else { return nil } // pointer between screens: keep waiting
        guard let current = settled else {
            settled = screen
            return screen
        }
        if screen == current {
            candidate = nil
            return nil
        }
        if candidate?.id != screen {
            candidate = (screen, now)
        }
        if let deadline, now >= deadline {
            settled = screen
            candidate = nil
            return screen
        }
        return nil
    }

    /// Settles immediately, e.g. when the settled screen was disconnected.
    mutating func force(_ screen: CGDirectDisplayID?) {
        settled = screen
        candidate = nil
    }
}
