import AppKit
import os

/// Shows the next calendar event from 5 min before it starts until 5 min
/// after, with a Join button for video calls. Off without calendar access.
@MainActor
@Observable
final class CalendarManager {
    static let activityID = "calendar"
    /// Privacy & Security → Calendars, to allow it later.
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
    /// Re-read at least this often (e.g. after midnight), besides changes.
    static let reloadInterval: TimeInterval = 60 * 60

    private(set) var authorization: CalendarAuthorization = .notDetermined
    private(set) var activity: CalendarActivity?

    @ObservationIgnored private let store: IslandStore
    @ObservationIgnored private let source: any CalendarSource
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let openURL: (URL) -> Void
    @ObservationIgnored private var events: [UpcomingEvent] = []
    @ObservationIgnored private var loadedAt: Date?
    /// Events the user joined; not shown again.
    @ObservationIgnored private var dismissed: Set<String> = []
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Calendar")

    init(
        store: IslandStore,
        source: any CalendarSource = EventKitCalendarSource(),
        now: @escaping () -> Date = Date.init,
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.store = store
        self.source = source
        self.now = now
        self.openURL = openURL
    }

    func start() {
        source.onChange = { [weak self] in self?.reload() }
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .NSSystemClockDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        })
        reload()
    }

    /// Asks for calendar access (menu bar: "Allow Calendar…").
    func requestAccess() async {
        authorization = await source.requestAccess()
        Self.logger.info("Calendar access: \(String(describing: self.authorization), privacy: .public)")
        reload()
    }

    /// Reads the next 24 hours again.
    func reload() {
        authorization = source.authorization
        let time = now()
        guard authorization == .granted else {
            events = []
            refresh()
            return
        }
        events = source.events(from: time.addingTimeInterval(-CalendarSchedule.gracePeriod), to: time.addingTimeInterval(CalendarSchedule.lookAhead))
        loadedAt = time
        dismissed = dismissed.filter { id in events.contains { $0.id == id } }
        refresh()
    }

    /// Shows or hides the event for the current time and schedules the
    /// next change.
    func refresh() {
        let time = now()
        if let loadedAt, time.timeIntervalSince(loadedAt) >= Self.reloadInterval { return reload() }

        if let shown = CalendarSchedule.shown(events, now: time, dismissed: dismissed) {
            if let activity {
                activity.update(shown)
            } else {
                let activity = CalendarActivity(event: shown)
                activity.onJoin = { [weak self] in self?.join() }
                self.activity = activity
                store.upsert(activity)
                Self.logger.info("Showing event starting \(CalendarFormat.time(shown.start), privacy: .public)")
            }
        } else if activity != nil {
            activity = nil
            store.remove(id: Self.activityID)
            Self.logger.info("Event hidden")
        }
        schedule(after: time)
    }

    /// Opens the video call and hides the event.
    func join() {
        guard let event = activity?.event, let url = event.joinURL else { return }
        Self.logger.info("Joining \(VideoCallLink.provider(for: url)?.name ?? "call", privacy: .public)")
        openURL(url)
        dismissed.insert(event.id)
        store.collapse()
        refresh()
    }

    private func schedule(after time: Date) {
        deadlineTask?.cancel()
        let change = CalendarSchedule.nextChange(events, now: time, dismissed: dismissed)
        let next = min(change ?? .distantFuture, (loadedAt ?? time).addingTimeInterval(Self.reloadInterval))
        let delay = max(next.timeIntervalSince(time), 0.05)
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay), tolerance: .milliseconds(10))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}
