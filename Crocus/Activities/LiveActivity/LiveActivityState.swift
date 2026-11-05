import Foundation

/// Values and lifecycle of one Live Activity, as a pure value (time is
/// passed in): running → ended with a result, shown for 3 s, then removed;
/// marked stale after 8 h without updates.
struct LiveActivityState: Equatable, Sendable {
    /// The result stays visible this long after `end`.
    static let resultDuration: TimeInterval = 3
    /// …and at most this long, even while the user has it expanded.
    static let maxTimeAfterEnd: TimeInterval = 30
    /// No update for this long → "No updates".
    static let staleAfter: TimeInterval = 8 * 60 * 60

    enum Phase: Equatable, Sendable {
        case running
        case ended(LiveActivityResult, text: String?, at: Date)
    }

    let id: String
    var title: String
    var symbol: String
    var progress: LiveActivityProgress
    var status: String?
    var action: LiveActivityAction?
    var source: String
    private(set) var startedAt: Date
    private(set) var lastUpdate: Date
    private(set) var phase: Phase = .running

    init(id: String, fields: LiveActivityFields, now: Date) {
        self.id = id
        title = fields.title ?? id
        symbol = fields.symbol ?? LiveActivityValidation.fallbackSymbol
        progress = fields.progress ?? .indeterminate
        status = fields.status
        action = fields.action
        source = fields.source ?? LiveActivityValidation.defaultSource
        startedAt = now
        lastUpdate = now
    }

    var isRunning: Bool { phase == .running }

    /// Applies an update; ignored once ended. Returns whether it applied.
    @discardableResult
    mutating func apply(_ fields: LiveActivityFields, now: Date) -> Bool {
        guard isRunning else { return false }
        if let title = fields.title { self.title = title }
        if let symbol = fields.symbol { self.symbol = symbol }
        if let progress = fields.progress { self.progress = progress }
        if let status = fields.status { self.status = status }
        if let action = fields.action { self.action = action }
        if let source = fields.source { self.source = source }
        lastUpdate = now
        return true
    }

    /// Restart with the same id: new values, running again.
    mutating func restart(_ fields: LiveActivityFields, now: Date) {
        self = LiveActivityState(id: id, fields: fields, now: now)
    }

    mutating func end(_ result: LiveActivityResult, text: String?, now: Date) {
        guard isRunning else { return }
        if result == .success { progress = .value(1) }
        phase = .ended(result, text: text, at: now)
        lastUpdate = now
    }

    func isStale(now: Date) -> Bool {
        isRunning && now.timeIntervalSince(lastUpdate) >= Self.staleAfter
    }

    /// Ended activities go after 3 s – unless the user is looking at the
    /// expanded card, then when it collapses, but never later than 30 s.
    func shouldRemove(now: Date, isExpanded: Bool) -> Bool {
        guard case .ended(_, _, let at) = phase else { return false }
        let elapsed = now.timeIntervalSince(at)
        if elapsed >= Self.maxTimeAfterEnd { return true }
        return elapsed >= Self.resultDuration && !isExpanded
    }

    /// When something changes next: removal or becoming stale.
    func nextDeadline(now: Date) -> Date? {
        switch phase {
        case .ended(_, _, let at):
            let removal = at.addingTimeInterval(Self.resultDuration)
            return removal > now ? removal : min(now.addingTimeInterval(1), at.addingTimeInterval(Self.maxTimeAfterEnd))
        case .running:
            let stale = lastUpdate.addingTimeInterval(Self.staleAfter)
            return stale > now ? stale : nil
        }
    }
}
