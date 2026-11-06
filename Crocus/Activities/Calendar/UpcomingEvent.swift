import Foundation

/// A calendar event as Crocus needs it, as a pure value (EventKit stays in
/// `EventKitCalendarSource`).
struct UpcomingEvent: Equatable, Sendable, Identifiable {
    /// sRGB colour of the calendar.
    struct RGB: Equatable, Sendable {
        var red: Double
        var green: Double
        var blue: Double
    }

    /// Unique per occurrence: repeating events share EventKit's identifier.
    let id: String
    var title: String
    var start: Date
    var end: Date
    var color: RGB?
    var location: String?
    var attendeeCount: Int
    var isAllDay: Bool
    /// The user declined it.
    var isDeclined: Bool
    var isCanceled: Bool
    /// A detected video call link (Zoom, Meet, Teams, FaceTime, Webex).
    var joinURL: URL?

    init(
        id: String, title: String, start: Date, end: Date, color: RGB? = nil,
        location: String? = nil, notes: String? = nil, url: URL? = nil, attendeeCount: Int = 0,
        isAllDay: Bool = false, isDeclined: Bool = false, isCanceled: Bool = false
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Event" : title
        self.start = start
        self.end = end
        self.color = color
        self.location = location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.attendeeCount = attendeeCount
        self.isAllDay = isAllDay
        self.isDeclined = isDeclined
        self.isCanceled = isCanceled
        joinURL = VideoCallLink.find(in: [url?.absoluteString, location, notes])
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
