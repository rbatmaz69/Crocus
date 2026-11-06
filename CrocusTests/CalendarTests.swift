import Foundation
import Testing
@testable import Crocus

@Suite struct VideoCallLinkTests {
    @Test(arguments: [
        ("https://us02web.zoom.us/j/81234567890?pwd=abc", VideoCallLink.Provider.zoom),
        ("https://zoom.us/my/someone", .zoom),
        ("https://meet.google.com/abc-defg-hij", .meet),
        ("https://teams.microsoft.com/l/meetup-join/19%3ameeting_x%40thread.v2/0?context=y", .teams),
        ("https://teams.live.com/meet/9876543210", .teams),
        ("https://facetime.apple.com/join#v=1&p=abc&k=def", .faceTime),
        ("https://company.webex.com/meet/someone", .webex),
        ("https://company.webex.com/company/j.php?MTID=m123", .webex),
    ])
    func recognises(_ string: String, _ provider: VideoCallLink.Provider) throws {
        #expect(VideoCallLink.provider(for: try #require(URL(string: string))) == provider)
    }

    @Test(arguments: [
        "https://zoom.us", "https://zoom.us/pricing", "http://meet.google.com/abc-defg-hij",
        "https://meet.google.com/", "https://meet.google.com.evil.com/abc-defg-hij", "https://notzoom.us/j/1",
        "https://teams.microsoft.com/", "https://www.webex.com/pricing", "https://example.com/j/123",
    ])
    func ignores(_ string: String) throws {
        #expect(VideoCallLink.provider(for: try #require(URL(string: string))) == nil)
    }

    @Test func findsTheLinkInNotes() {
        let notes = """
        Agenda: sprint review
        Join: https://meet.google.com/abc-defg-hij
        Docs: https://example.com/doc
        """
        #expect(VideoCallLink.find(in: [nil, "Room 4", notes])?.absoluteString == "https://meet.google.com/abc-defg-hij")
        #expect(VideoCallLink.find(in: ["https://example.com", "nothing here"]) == nil)
    }

    @Test func urlFieldWinsOverNotes() {
        let event = UpcomingEvent(
            id: "a", title: "A", start: .now, end: .now,
            notes: "https://meet.google.com/aaa-bbbb-ccc", url: URL(string: "https://zoom.us/j/1")
        )
        #expect(event.joinURL?.host() == "zoom.us")
    }
}

@Suite struct CalendarScheduleTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func event(_ id: String, startsIn minutes: Double, link: Bool = false, allDay: Bool = false, declined: Bool = false, canceled: Bool = false) -> UpcomingEvent {
        let start = t0.addingTimeInterval(minutes * 60)
        return UpcomingEvent(
            id: id, title: id, start: start, end: start.addingTimeInterval(1800),
            notes: link ? "https://meet.google.com/abc-defg-hij" : nil,
            isAllDay: allDay, isDeclined: declined, isCanceled: canceled
        )
    }

    @Test func fiveMinutesBeforeUntilFiveAfter() {
        let events = [event("a", startsIn: 10)]
        #expect(CalendarSchedule.shown(events, now: t0 + 299) == nil)          // 5:01 before
        #expect(CalendarSchedule.shown(events, now: t0 + 300)?.id == "a")      // 5:00 before
        #expect(CalendarSchedule.shown(events, now: t0 + 600)?.id == "a")      // start
        #expect(CalendarSchedule.shown(events, now: t0 + 899)?.id == "a")
        #expect(CalendarSchedule.shown(events, now: t0 + 900) == nil)          // 5 min after
        #expect(CalendarSchedule.nextChange(events, now: t0) == t0 + 300)
        #expect(CalendarSchedule.nextChange(events, now: t0 + 300) == t0 + 900)
        #expect(CalendarSchedule.nextChange(events, now: t0 + 900) == nil)
    }

    @Test func ignoresAllDayDeclinedAndCanceled() {
        let events = [
            event("allDay", startsIn: 2, allDay: true),
            event("declined", startsIn: 2, declined: true),
            event("canceled", startsIn: 2, canceled: true),
        ]
        #expect(CalendarSchedule.shown(events, now: t0) == nil)
        #expect(CalendarSchedule.nextChange(events, now: t0) == nil)
    }

    @Test func earliestFirstThenVideoCall() {
        #expect(CalendarSchedule.shown([event("later", startsIn: 4), event("sooner", startsIn: 2)], now: t0)?.id == "sooner")
        #expect(CalendarSchedule.shown([event("plain", startsIn: 3), event("call", startsIn: 3, link: true)], now: t0)?.id == "call")
        // The running one stays until its grace period ends, then the next.
        let events = [event("running", startsIn: -4), event("next", startsIn: 3)]
        #expect(CalendarSchedule.shown(events, now: t0)?.id == "running")
        #expect(CalendarSchedule.shown(events, now: t0 + 60)?.id == "next")
    }

    @Test func joinedEventIsNotShownAgain() {
        let events = [event("a", startsIn: 2)]
        #expect(CalendarSchedule.shown(events, now: t0, dismissed: ["a"]) == nil)
        #expect(CalendarSchedule.nextChange(events, now: t0, dismissed: ["a"]) == nil)
    }
}

@Suite struct CalendarFormatTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func countdown() {
        let start = t0 + 300
        #expect(CalendarFormat.countdown(to: start, now: t0) == "5 min")
        #expect(CalendarFormat.countdown(to: start, now: t0 + 1) == "5 min")
        #expect(CalendarFormat.countdown(to: start, now: t0 + 240) == "1 min")
        #expect(CalendarFormat.countdown(to: start, now: t0 + 299.5) == "1 min")
        #expect(CalendarFormat.countdown(to: start, now: t0 + 300) == "Now")
        #expect(CalendarFormat.headerStatus(to: start, now: t0) == "In 5 min")
        #expect(CalendarFormat.headerStatus(to: start, now: t0 + 400) == "Now")
    }

    @Test func subtitle() {
        let time: (Date) -> String = { "T\(Int($0.timeIntervalSince(self.t0) / 60))" }
        let call = UpcomingEvent(id: "a", title: "Sprint Review", start: t0, end: t0 + 1800, notes: "https://meet.google.com/abc-defg-hij", attendeeCount: 4)
        #expect(CalendarFormat.subtitle(call, timeStyle: time) == "T0–T30 · Video call · 4 attendees")
        let room = UpcomingEvent(id: "b", title: "1:1", start: t0, end: t0 + 1800, location: "Room 4\nBuilding B", attendeeCount: 1)
        #expect(CalendarFormat.subtitle(room, timeStyle: time) == "T0–T30 · Room 4 · 1 attendee")
        let alone = UpcomingEvent(id: "c", title: "Focus", start: t0, end: t0 + 1800)
        #expect(CalendarFormat.subtitle(alone, timeStyle: time) == "T0–T30")
    }

    @Test func accessibility() {
        let call = UpcomingEvent(id: "a", title: "Sprint Review", start: t0 + 300, end: t0 + 1800, notes: "https://meet.google.com/abc-defg-hij")
        #expect(CalendarFormat.accessibilityLabel(call, now: t0) == "Sprint Review in 5 minutes, video call")
        #expect(CalendarFormat.accessibilityLabel(call, now: t0 + 240) == "Sprint Review in 1 minute, video call")
        #expect(CalendarFormat.accessibilityLabel(call, now: t0 + 400) == "Sprint Review, now, video call")
    }

    @Test func emptyTitle() {
        #expect(UpcomingEvent(id: "a", title: "  ", start: t0, end: t0).title == "Event")
    }
}

@MainActor
final class FakeCalendarSource: CalendarSource {
    var authorization: CalendarAuthorization = .granted
    var answerToRequest: CalendarAuthorization = .granted
    var stored: [UpcomingEvent] = []
    var onChange: (() -> Void)?
    var queries: [(Date, Date)] = []

    func requestAccess() async -> CalendarAuthorization {
        authorization = answerToRequest
        return authorization
    }

    func events(from start: Date, to end: Date) -> [UpcomingEvent] {
        queries.append((start, end))
        return authorization == .granted ? stored.filter { $0.end > start && $0.start < end } : []
    }
}

@MainActor
@Suite struct CalendarManagerTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_000_000) }
    final class Opened { var urls: [URL] = [] }

    let clock = Clock()
    let opened = Opened()
    let source = FakeCalendarSource()
    let store: IslandStore

    init() {
        let suite = "CalendarManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        store = IslandStore(defaults: defaults)
    }

    func manager() -> CalendarManager {
        let clock = clock, opened = opened
        return CalendarManager(store: store, source: source, now: { clock.now }, openURL: { opened.urls.append($0) })
    }

    func event(startsIn minutes: Double, link: Bool = true) -> UpcomingEvent {
        let start = clock.now.addingTimeInterval(minutes * 60)
        return UpcomingEvent(id: "e\(minutes)", title: "Sprint Review", start: start, end: start + 1800,
                             notes: link ? "https://meet.google.com/abc-defg-hij" : nil, attendeeCount: 4)
    }

    @Test func appearsFiveMinutesBeforeAndGoesAfter() {
        source.stored = [event(startsIn: 7)]
        let manager = manager()
        manager.reload()
        #expect(manager.activity == nil)

        clock.now += 120
        manager.refresh()
        #expect(store.primaryActivity?.kind == .calendar)
        #expect(manager.activity?.event.title == "Sprint Review")

        clock.now += 600 // 5 min after start
        manager.refresh()
        #expect(manager.activity == nil)
        #expect(store.presentation == .idle)
    }

    @Test func readsOnlyTheNextDay() throws {
        let manager = manager()
        manager.reload()
        let (start, end) = try #require(source.queries.last)
        #expect(start == clock.now - 300)
        #expect(end == clock.now + 86_400)
    }

    @Test func joinOpensTheLinkAndHides() {
        source.stored = [event(startsIn: 3)]
        let manager = manager()
        manager.reload()
        manager.join()
        #expect(opened.urls.map(\.absoluteString) == ["https://meet.google.com/abc-defg-hij"])
        #expect(manager.activity == nil)
        manager.reload() // still hidden after a calendar change
        #expect(manager.activity == nil)
    }

    @Test func noJoinWithoutALink() {
        source.stored = [event(startsIn: 3, link: false)]
        let manager = manager()
        manager.reload()
        manager.join()
        #expect(opened.urls.isEmpty)
        #expect(manager.activity != nil)
    }

    @Test func deniedMeansOff() async {
        source.authorization = .notDetermined
        source.answerToRequest = .denied
        source.stored = [event(startsIn: 3)]
        let manager = manager()
        manager.reload()
        #expect(manager.authorization == .notDetermined)
        #expect(manager.activity == nil)

        await manager.requestAccess()
        #expect(manager.authorization == .denied)
        #expect(manager.activity == nil)
    }

    @Test func grantingShowsIt() async {
        source.authorization = .notDetermined
        source.stored = [event(startsIn: 3)]
        let manager = manager()
        manager.reload()
        await manager.requestAccess()
        #expect(manager.authorization == .granted)
        #expect(manager.activity != nil)
    }

    @Test func calendarChangesAreReloaded() {
        let manager = manager()
        manager.start()
        #expect(manager.activity == nil)
        source.stored = [event(startsIn: 2)]
        source.onChange?()
        #expect(manager.activity != nil)
        source.stored = []
        source.onChange?()
        #expect(manager.activity == nil)
    }
}
