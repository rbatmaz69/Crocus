import AppIntents

/// Makes the Live Activity and timer actions show up in Spotlight and Siri without the
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
        AppShortcut(
            intent: StartTimerIntent(),
            phrases: ["Start a timer in \(.applicationName)", "Set a timer in \(.applicationName)"],
            shortTitle: "Start Timer",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: StartStopwatchIntent(),
            phrases: ["Start the stopwatch in \(.applicationName)"],
            shortTitle: "Start Stopwatch",
            systemImageName: "stopwatch"
        )
        AppShortcut(
            intent: ControlTimerIntent(),
            phrases: ["Pause the timer in \(.applicationName)", "Stop the timer in \(.applicationName)"],
            shortTitle: "Control Timer",
            systemImageName: "pause.circle"
        )
    }
}
