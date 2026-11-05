import Foundation
import Testing
@testable import Crocus

@Suite struct LiveActivityStateTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func state(progress: LiveActivityProgress? = .value(0.4)) -> LiveActivityState {
        LiveActivityState(id: "build", fields: LiveActivityFields(title: "Build", progress: progress), now: t0)
    }

    @Test func defaults() {
        let s = LiveActivityState(id: "x", fields: LiveActivityFields(), now: t0)
        #expect(s.title == "x")
        #expect(s.symbol == LiveActivityValidation.fallbackSymbol)
        #expect(s.progress == .indeterminate)
        #expect(s.source == LiveActivityValidation.defaultSource)
    }

    @Test func updateKeepsUnsetFields() {
        var s = state()
        s.apply(LiveActivityFields(status: "half"), now: at(10))
        #expect(s.progress == .value(0.4))
        #expect(s.status == "half")
        #expect(s.title == "Build")
    }

    @Test func resultIsShownThreeSeconds() {
        var s = state()
        s.end(.success, text: nil, now: at(60))
        #expect(s.progress == .value(1))
        #expect(!s.shouldRemove(now: at(62.9), isExpanded: false))
        #expect(s.shouldRemove(now: at(63), isExpanded: false))
        #expect(s.nextDeadline(now: at(60)) == at(63))
    }

    @Test func expandedResultStaysUpToThirtySeconds() {
        var s = state()
        s.end(.failure, text: "Broke", now: at(0))
        #expect(!s.shouldRemove(now: at(10), isExpanded: true))
        #expect(!s.shouldRemove(now: at(29.9), isExpanded: true))
        #expect(s.shouldRemove(now: at(30), isExpanded: true))
    }

    @Test func noUpdatesAfterEnd() {
        var s = state()
        s.end(.cancelled, text: nil, now: at(0))
        let applied = s.apply(LiveActivityFields(progress: .value(0.9)), now: at(1))
        #expect(!applied)
        #expect(s.phase == .ended(.cancelled, text: nil, at: at(0)))
    }

    @Test func staleAfterEightHours() {
        let s = state()
        #expect(!s.isStale(now: at(8 * 3600 - 60)))
        #expect(s.isStale(now: at(8 * 3600)))
        #expect(s.nextDeadline(now: at(0)) == at(8 * 3600))
    }

    @Test func updateResetsStaleness() {
        var s = state()
        s.apply(LiveActivityFields(status: "still here"), now: at(7 * 3600))
        #expect(!s.isStale(now: at(8 * 3600)))
        #expect(s.isStale(now: at(15 * 3600)))
    }

    @Test func restartAfterEnd() {
        var s = state()
        s.end(.success, text: nil, now: at(5))
        s.restart(LiveActivityFields(title: "Build 2"), now: at(10))
        #expect(s.isRunning)
        #expect(s.title == "Build 2")
        #expect(s.startedAt == at(10))
    }
}
