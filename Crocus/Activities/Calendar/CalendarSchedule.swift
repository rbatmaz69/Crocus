import Foundation

/// Which event the island shows when, as pure logic: from 5 min before
/// it starts until 5 min after (for joining late). All-day, declined and
/// cancelled events are ignored, and so is an event the user joined.
enum CalendarSchedule {
    static let leadTime: TimeInterval = 5 * 60
    static let gracePeriod: TimeInterval = 5 * 60
    /// Events are read this far ahead.
    static let lookAhead: TimeInterval = 24 * 60 * 60

    static func isRelevant(_ event: UpcomingEvent) -> Bool {
        !event.isAllDay && !event.isDeclined && !event.isCanceled
    }

    static func appears(_ event: UpcomingEvent) -> Date { event.start.addingTimeInterval(-leadTime) }
    static func disappears(_ event: UpcomingEvent) -> Date { event.start.addingTimeInterval(gracePeriod) }

    /// The earliest event in its window; at the same start, one with a
    /// video call first.
    static func shown(_ events: [UpcomingEvent], now: Date, dismissed: Set<String> = []) -> UpcomingEvent? {
        events
            .filter { isRelevant($0) && !dismissed.contains($0.id) && now >= appears($0) && now < disappears($0) }
            .min { a, b in
                if a.start != b.start { return a.start < b.start }
                if (a.joinURL != nil) != (b.joinURL != nil) { return a.joinURL != nil }
                return a.title < b.title
            }
    }

    /// When the shown event can change next.
    static func nextChange(_ events: [UpcomingEvent], now: Date, dismissed: Set<String> = []) -> Date? {
        events
            .filter { isRelevant($0) && !dismissed.contains($0.id) }
            .flatMap { [appears($0), disappears($0)] }
            .filter { $0 > now }
            .min()
    }
}

/// Texts for the calendar views.
enum CalendarFormat {
    /// "5 min" … "1 min", then "Now".
    static func countdown(to start: Date, now: Date) -> String {
        let seconds = start.timeIntervalSince(now)
        guard seconds > 0 else { return "Now" }
        return "\(Int((seconds / 60).rounded(.up))) min"
    }

    /// "In 5 min" / "Now".
    static func headerStatus(to start: Date, now: Date) -> String {
        let countdown = countdown(to: start, now: now)
        return countdown == "Now" ? "Now" : "In \(countdown)"
    }

    /// "14:30–15:00 · Video call · 4 attendees"; the location instead of
    /// "Video call" without a link; no attendees part for 0.
    static func subtitle(_ event: UpcomingEvent, timeStyle: (Date) -> String = time) -> String {
        var parts = ["\(timeStyle(event.start))–\(timeStyle(event.end))"]
        if event.joinURL != nil {
            parts.append("Video call")
        } else if let location = event.location?.split(whereSeparator: \.isNewline).first {
            parts.append(String(location))
        }
        if event.attendeeCount > 0 {
            parts.append("\(event.attendeeCount) attendee\(event.attendeeCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    /// "Sprint Review in 5 minutes, video call" / "Sprint Review, now".
    static func accessibilityLabel(_ event: UpcomingEvent, now: Date) -> String {
        let seconds = event.start.timeIntervalSince(now)
        var label: String
        if seconds > 0 {
            let minutes = Int((seconds / 60).rounded(.up))
            label = "\(event.title) in \(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            label = "\(event.title), now"
        }
        if event.joinURL != nil { label += ", video call" }
        return label
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
