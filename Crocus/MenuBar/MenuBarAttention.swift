import SwiftUI

/// A permission or setup step the menu bar panel asks for under "Needs your
/// permission" (#61). While any is listed, the menu bar icon carries a dot.
struct MenuBarAttentionItem: Equatable, Identifiable, Sendable {
    enum Subject: Equatable, Sendable {
        case calendar
        case player(MusicPlayer)
        case bluetooth
        case downloadsFolder
    }

    enum Action: Equatable, Sendable {
        /// Ask macOS (the system prompt appears).
        case request
        /// Denied before: only System Settings can turn it back on.
        case openSystemSettings
        case chooseFolder
    }

    let subject: Subject
    let action: Action

    var id: String {
        switch subject {
        case .calendar: "calendar"
        case .player(let player): "player.\(player.rawValue)"
        case .bluetooth: "bluetooth"
        case .downloadsFolder: "downloads"
        }
    }

    var title: String {
        switch subject {
        case .calendar: "Calendar"
        case .player(let player): player.displayName
        case .bluetooth: "Bluetooth"
        case .downloadsFolder: "Downloads"
        }
    }

    var detail: String {
        switch subject {
        case .calendar: "Events are off"
        case .player: "Now Playing is off"
        case .bluetooth: "Device events are off"
        case .downloadsFolder: "No folder chosen"
        }
    }

    var buttonTitle: String {
        switch action {
        case .request: "Allow"
        case .openSystemSettings: "Open…"
        case .chooseFolder: "Choose…"
        }
    }

    var symbol: String {
        switch subject {
        case .calendar: "calendar"
        case .player: "music.note"
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .downloadsFolder: "arrow.down"
        }
    }

    var tint: Color {
        switch subject {
        case .calendar: .red
        case .player: .pink
        case .bluetooth: .blue
        case .downloadsFolder: .cyan
        }
    }
}

enum MenuBarAttention {
    /// What is missing, in a fixed order. Types switched off in Settings
    /// never ask; players that aren't installed (`unavailable`) neither.
    static func items(
        calendar: CalendarAuthorization,
        players: [MusicPlayer: PlayerPermission],
        bluetooth: BluetoothAccess,
        downloadsFolder: URL?,
        disabledActivities: Set<ActivityKind> = [],
        disabledEvents: Set<EventKind> = []
    ) -> [MenuBarAttentionItem] {
        var items: [MenuBarAttentionItem] = []

        if !disabledActivities.contains(.calendar), let action = action(for: calendar) {
            items.append(MenuBarAttentionItem(subject: .calendar, action: action))
        }
        if !disabledActivities.contains(.music) {
            for player in MusicPlayer.allCases {
                switch players[player] {
                case .notDetermined: items.append(MenuBarAttentionItem(subject: .player(player), action: .request))
                case .denied: items.append(MenuBarAttentionItem(subject: .player(player), action: .openSystemSettings))
                case .granted, .unavailable, nil: break
                }
            }
        }
        if !disabledEvents.contains(.bluetooth), let action = action(for: bluetooth) {
            items.append(MenuBarAttentionItem(subject: .bluetooth, action: action))
        }
        if !disabledActivities.contains(.download), downloadsFolder == nil {
            items.append(MenuBarAttentionItem(subject: .downloadsFolder, action: .chooseFolder))
        }
        return items
    }

    private static func action(for authorization: CalendarAuthorization) -> MenuBarAttentionItem.Action? {
        switch authorization {
        case .granted: nil
        case .notDetermined: .request
        case .denied: .openSystemSettings
        }
    }

    private static func action(for access: BluetoothAccess) -> MenuBarAttentionItem.Action? {
        switch access {
        case .granted: nil
        case .notDetermined: .request
        case .denied: .openSystemSettings
        }
    }
}

/// The status line under "Crocus" in the panel's header.
enum MenuBarStatus {
    static func line(activityCount: Int, screenName: String?, islandHidden: Bool) -> String {
        if islandHidden { return "Island hidden" }
        guard activityCount > 0 else { return "No activities" }
        let count = activityCount == 1 ? "1 activity" : "\(activityCount) activities"
        guard let screenName, !screenName.isEmpty else { return count }
        return "\(count) · \(screenName)"
    }
}
