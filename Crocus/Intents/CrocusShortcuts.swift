import AppIntents

/// Makes the Live Activity actions show up in Spotlight and Siri without the
/// user building a shortcut first.
struct CrocusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartLiveActivityIntent(),
            phrases: ["Start an activity in \(.applicationName)", "Show an activity in \(.applicationName)"],
            shortTitle: "Start Activity",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: UpdateLiveActivityIntent(),
            phrases: ["Update an activity in \(.applicationName)"],
            shortTitle: "Update Progress",
            systemImageName: "arrow.clockwise.circle"
        )
        AppShortcut(
            intent: EndLiveActivityIntent(),
            phrases: ["End an activity in \(.applicationName)"],
            shortTitle: "End Activity",
            systemImageName: "checkmark.circle"
        )
    }
}
