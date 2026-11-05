import Foundation
import Testing
@testable import Crocus

@Suite struct IslandStateTests {
    let t0 = ContinuousClock.now
    func at(_ ms: Int) -> ContinuousClock.Instant { t0 + .milliseconds(ms) }

    static func activity(_ id: String, _ kind: ActivityKind, age: TimeInterval = 0) -> ActivityEntry {
        ActivityEntry(id: id, kind: kind, startedAt: Date(timeIntervalSince1970: 1000 - age))
    }

    static func event(_ id: String, _ kind: EventKind, ms: Int = 2500) -> EventEntry {
        EventEntry(id: id, kind: kind, duration: .milliseconds(ms))
    }

    let timer = activity("timer", .timer)
    let music = activity("music", .music)
    let camera = activity("camera", .cameraMicrophone)

    // MARK: - State model

    @Test func idleToCompactToMinimal() {
        var state = IslandState()
        #expect(state.display == .idle)
        state.upsert(music)
        #expect(state.display == .compact(primary: "music"))
        state.upsert(timer)
        #expect(state.display == .minimal(primary: "timer", secondary: "music"))
        #expect(state.display.presentation == .minimal)
    }

    @Test func higherPriorityTakesTheMainShape() {
        var state = IslandState()
        state.upsert(timer)
        state.upsert(music)
        state.upsert(camera)
        #expect(state.display == .minimal(primary: "camera", secondary: "timer"))
    }

    @Test func removingFallsBack() {
        var state = IslandState()
        state.upsert(timer)
        state.upsert(music)
        state.remove(id: "timer", now: at(0))
        #expect(state.display == .compact(primary: "music"))
        state.remove(id: "music", now: at(0))
        #expect(state.display == .idle)
    }

    @Test func updatingKeepsPosition() {
        var state = IslandState()
        state.upsert(timer)
        state.upsert(music)
        state.upsert(Self.activity("timer", .timer, age: 5))
        #expect(state.activities.map(\.id) == ["timer", "music"])
    }

    @Test func expandAndCollapse() {
        var state = IslandState()
        state.upsert(timer)
        do { let result = state.expand(); #expect(result) }
        #expect(state.display == .expanded("timer"))
        do { let result = state.collapse(now: at(0)); #expect(result) }
        #expect(state.display == .compact(primary: "timer"))
    }

    @Test func expandTheDropActivity() {
        var state = IslandState()
        state.upsert(timer)
        state.upsert(music)
        do { let result = state.expand(id: "music"); #expect(result) }
        #expect(state.display == .expanded("music"))
        state.collapse(now: at(0))
        #expect(state.display == .minimal(primary: "timer", secondary: "music"))
    }

    @Test func expandIsIgnoredWhenIdleOrUnknown() {
        var state = IslandState()
        do { let result = state.expand(); #expect(!result) }
        state.upsert(timer)
        do { let result = state.expand(id: "nope"); #expect(!result) }
        #expect(state.display == .compact(primary: "timer"))
    }

    @Test func collapseWhenNotExpandedDoesNothing() {
        var state = IslandState()
        state.upsert(timer)
        do { let result = state.collapse(now: at(0)); #expect(!result) }
    }

    @Test func expandedActivityEndingCollapses() {
        var state = IslandState()
        state.upsert(timer)
        state.upsert(music)
        state.expand()
        state.remove(id: "timer", now: at(0))
        #expect(state.display == .compact(primary: "music"))
    }

    @Test func priorityChangeResorts() {
        var state = IslandState()
        state.upsert(timer)
        state.upsert(music)
        state.setPriority(ActivityPriority(storedOrder: ["music"]))
        #expect(state.display == .minimal(primary: "music", secondary: "timer"))
    }

    // MARK: - Events

    @Test(arguments: [0, 1, 2])
    func eventOverlaysAndReturns(activityCount: Int) {
        var state = IslandState()
        for entry in [timer, music].prefix(activityCount) { state.upsert(entry) }
        let before = state.display

        state.post(Self.event("e", .charging), now: at(0))
        #expect(state.display == .event("e"))
        #expect(state.display.presentation == .compact)
        #expect(state.nextDeadline == at(2500))

        state.tick(now: at(2499))
        #expect(state.display == .event("e"))
        state.tick(now: at(2500))
        #expect(state.display == before)
        #expect(state.nextDeadline == nil)
    }

    @Test func eventsRunOneAfterAnother() {
        var state = IslandState()
        state.post(Self.event("charge", .charging), now: at(0))
        state.post(Self.event("bt", .bluetooth, ms: 2000), now: at(500))
        #expect(state.display == .event("charge"))
        state.tick(now: at(2500))
        #expect(state.display == .event("bt"))
        #expect(state.nextDeadline == at(4500))
        state.tick(now: at(4500))
        #expect(state.display == .idle)
    }

    @Test func sameKindReplacesRunningEvent() {
        var state = IslandState()
        state.post(Self.event("a", .charging), now: at(0))
        state.post(Self.event("b", .charging), now: at(1000))
        #expect(state.display == .event("b"))
        #expect(state.nextDeadline == at(3500))
        #expect(state.pendingEvents.isEmpty)
    }

    @Test func sameKindReplacesPendingEvent() {
        var state = IslandState()
        state.post(Self.event("charge", .charging), now: at(0))
        state.post(Self.event("bt1", .bluetooth), now: at(100))
        state.post(Self.event("bt2", .bluetooth), now: at(200))
        #expect(state.pendingEvents.map(\.entry.id) == ["bt2"])
    }

    @Test func eventWhileExpandedShowsAfterCollapse() {
        var state = IslandState()
        state.upsert(timer)
        state.expand()
        state.post(Self.event("e", .charging), now: at(0))
        #expect(state.display == .expanded("timer"))
        state.collapse(now: at(5000))
        #expect(state.display == .event("e"))
        #expect(state.nextDeadline == at(7500))
    }

    @Test func staleEventWhileExpandedIsDropped() {
        var state = IslandState()
        state.upsert(timer)
        state.expand()
        state.post(Self.event("e", .charging), now: at(0))
        state.collapse(now: at(5001))
        #expect(state.display == .compact(primary: "timer"))
        #expect(state.pendingEvents.isEmpty)
    }

    @Test func expandingEndsTheRunningEvent() {
        var state = IslandState()
        state.upsert(timer)
        state.post(Self.event("e", .charging), now: at(0))
        state.expand()
        #expect(state.display == .expanded("timer"))
        state.collapse(now: at(100))
        #expect(state.display == .compact(primary: "timer"))
    }
}

@Suite struct IslandStateCardTests {
    let t0 = ContinuousClock.now

    func state(_ ids: [(String, ActivityKind)]) -> IslandState {
        var state = IslandState()
        for (id, kind) in ids { state.upsert(ActivityEntry(id: id, kind: kind, startedAt: .distantPast)) }
        return state
    }

    @Test func nextAndPrevious() {
        var s = state([("cam", .cameraMicrophone), ("timer", .timer), ("music", .music)])
        s.expand()
        do { let moved = s.showNextCard(); #expect(moved) }
        #expect(s.display == .expanded("timer"))
        s.showNextCard()
        #expect(s.display == .expanded("music"))
        do { let moved = s.showNextCard(); #expect(!moved) }
        #expect(s.display == .expanded("music"))
        s.showPreviousCard()
        s.showPreviousCard()
        #expect(s.display == .expanded("cam"))
        do { let moved = s.showPreviousCard(); #expect(!moved) }
    }

    @Test func onlyWhileExpanded() {
        var s = state([("timer", .timer), ("music", .music)])
        do { let moved = s.showNextCard(); #expect(!moved) }
        #expect(s.display == .minimal(primary: "timer", secondary: "music"))
    }
}
