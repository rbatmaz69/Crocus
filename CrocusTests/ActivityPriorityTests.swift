import Foundation
import Testing
@testable import Crocus

@Suite struct ActivityPriorityTests {
    @Test func defaultOrder() {
        #expect(ActivityPriority.default.order == [.cameraMicrophone, .calendar, .timer, .liveActivity, .download, .music])
    }

    @Test func cameraStaysOnTop() {
        let priority = ActivityPriority(storedOrder: ["music", "cameraMicrophone", "timer"])
        #expect(priority.order.first == .cameraMicrophone)
        #expect(priority.order == [.cameraMicrophone, .music, .timer, .calendar, .liveActivity, .download])
    }

    @Test func cleansStoredOrder() {
        let priority = ActivityPriority(storedOrder: ["download", "bogus", "download", "calendar"])
        #expect(priority.order == [.cameraMicrophone, .download, .calendar, .timer, .liveActivity, .music])
        #expect(priority.storedOrder == ["download", "calendar", "timer", "liveActivity", "music"])
    }

    @Test func sortsByRankThenAgeThenID() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let entries = [
            ActivityEntry(id: "m", kind: .music, startedAt: t0),
            ActivityEntry(id: "t2", kind: .timer, startedAt: t0.addingTimeInterval(10)),
            ActivityEntry(id: "t1", kind: .timer, startedAt: t0),
            ActivityEntry(id: "tb", kind: .timer, startedAt: t0.addingTimeInterval(10)),
            ActivityEntry(id: "c", kind: .cameraMicrophone, startedAt: t0.addingTimeInterval(99)),
        ]
        #expect(ActivityPriority.default.sorted(entries).map(\.id) == ["c", "t1", "t2", "tb", "m"])
    }

    @Test func customOrderChangesRanking() {
        let entries = [
            ActivityEntry(id: "t", kind: .timer, startedAt: .distantPast),
            ActivityEntry(id: "m", kind: .music, startedAt: .distantPast),
        ]
        let musicFirst = ActivityPriority(storedOrder: ["music"])
        #expect(musicFirst.sorted(entries).map(\.id) == ["m", "t"])
    }
}
