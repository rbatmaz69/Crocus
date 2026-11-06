import AppKit
import EventKit
import os

enum CalendarAuthorization: Equatable, Sendable {
    case notDetermined
    case granted
    /// Denied, restricted or write-only: the activity is off.
    case denied
}

/// Where events come from; a fake in tests.
@MainActor
protocol CalendarSource: AnyObject {
    var authorization: CalendarAuthorization { get }
    func requestAccess() async -> CalendarAuthorization
    /// Events overlapping the interval, from all calendars.
    func events(from start: Date, to end: Date) -> [UpcomingEvent]
    /// Called when the calendar database changes.
    var onChange: (() -> Void)? { get set }
}

/// EventKit with full access – read only, and only the next 24 hours.
@MainActor
final class EventKitCalendarSource: CalendarSource {
    var onChange: (() -> Void)?

    private let eventStore = EKEventStore()
    private var observer: NSObjectProtocol?

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Calendar")

    init() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: eventStore, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onChange?() }
        }
    }

    var authorization: CalendarAuthorization {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func requestAccess() async -> CalendarAuthorization {
        do {
            _ = try await eventStore.requestFullAccessToEvents()
        } catch {
            Self.logger.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
        }
        eventStore.reset() // pick up the calendars now that access is granted
        return authorization
    }

    func events(from start: Date, to end: Date) -> [UpcomingEvent] {
        guard authorization == .granted else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        return eventStore.events(matching: predicate).map(UpcomingEvent.init)
    }
}

extension UpcomingEvent {
    init(_ event: EKEvent) {
        let base = event.eventIdentifier ?? event.calendarItemIdentifier
        let color = event.calendar?.cgColor
            .flatMap { NSColor(cgColor: $0)?.usingColorSpace(.sRGB) }
            .map { RGB(red: $0.redComponent, green: $0.greenComponent, blue: $0.blueComponent) }
        let me = event.attendees?.first(where: \.isCurrentUser)
        self.init(
            id: "\(base)@\(Int(event.startDate.timeIntervalSince1970))",
            title: event.title ?? "",
            start: event.startDate,
            end: event.endDate,
            color: color,
            location: event.structuredLocation?.title ?? event.location,
            notes: event.notes,
            url: event.url,
            attendeeCount: event.attendees?.count ?? 0,
            isAllDay: event.isAllDay,
            isDeclined: me?.participantStatus == .declined,
            isCanceled: event.status == .canceled
        )
    }
}
