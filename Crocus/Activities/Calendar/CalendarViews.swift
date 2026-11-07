import SwiftUI

extension UpcomingEvent {
    /// The calendar's colour; blue without one.
    var tint: Color {
        color.map { Color(.sRGB, red: $0.red, green: $0.green, blue: $0.blue) } ?? CrocusColors.progress
    }
}

/// Redraws every second, aligned to the start, so the minute count changes
/// exactly when it should.
struct CalendarTicking<Content: View>: View {
    let start: Date
    @ViewBuilder var content: (Date) -> Content

    var body: some View {
        TimelineView(.periodic(from: start.addingTimeInterval(-86_400), by: 1)) { context in
            content(context.date)
        }
    }
}

/// `calendar` symbol in the calendar's colour.
struct CalendarSymbol: View {
    let event: UpcomingEvent

    var body: some View {
        IslandCompactSymbol(systemName: "calendar", color: event.tint)
    }
}

/// Right wing: "5 min" … "1 min", "Now".
struct CalendarCountdown: View {
    let start: Date

    var body: some View {
        CalendarTicking(start: start) { now in
            IslandCompactValue(text: CalendarFormat.countdown(to: start, now: now))
        }
    }
}

/// Expanded header, right: "In 5 min" / "Now".
struct CalendarHeaderStatus: View {
    let start: Date

    var body: some View {
        CalendarTicking(start: start) { now in
            Text(CalendarFormat.headerStatus(to: start, now: now))
        }
    }
}

/// Expanded (board 07 · 4c): calendar colour as 4 pt bar, title,
/// "14:30–15:00 · Video call · 4 attendees", white Join button with a link.
struct CalendarCard: View {
    let activity: CalendarActivity

    var body: some View {
        let event = activity.event
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.tint)
                .frame(width: 4, height: 38)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .islandFont(CrocusTypography.title)
                    .lineLimit(1)
                Text(CalendarFormat.subtitle(event))
                    .islandFont(CrocusTypography.status)
                    .foregroundStyle(.islandSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if event.joinURL != nil {
                IslandButton(title: "Join", primary: true, systemImage: "video.fill") { activity.onJoin?() }
                    .accessibilityLabel("Join video call")
            }
        }
        .foregroundStyle(CrocusColors.primary)
    }
}
