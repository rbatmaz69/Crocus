import SwiftUI

/// The next calendar event, shown from 5 min before it starts.
@MainActor
@Observable
final class CalendarActivity: IslandActivity {
    private(set) var event: UpcomingEvent
    @ObservationIgnored var onJoin: (() -> Void)?

    init(event: UpcomingEvent) {
        self.event = event
    }

    func update(_ event: UpcomingEvent) {
        if event != self.event { self.event = event }
    }

    // MARK: IslandActivity

    var id: String { CalendarManager.activityID }
    var kind: ActivityKind { .calendar }
    var startedAt: Date { CalendarSchedule.appears(event) }
    var accessibilityLabel: String { CalendarFormat.accessibilityLabel(event, now: Date()) }

    var compactLeading: AnyView { AnyView(CalendarSymbol(event: event)) }
    var compactTrailing: AnyView { AnyView(CalendarCountdown(start: event.start)) }
    var compactTrailingReduced: AnyView {
        event.joinURL != nil ? AnyView(IslandCompactSymbol(systemName: "video.fill")) : compactTrailing
    }
    var minimal: AnyView { AnyView(CalendarSymbol(event: event)) }
    var expandedSource: AnyView { AnyView(Text("Calendar")) }
    var expandedStatus: AnyView { AnyView(CalendarHeaderStatus(start: event.start)) }
    var expandedContent: AnyView { AnyView(CalendarCard(activity: self)) }
}
