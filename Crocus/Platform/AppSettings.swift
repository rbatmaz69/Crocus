import Foundation

/// User defaults keys and defaults. The settings UI lands in #27; until then
/// the defaults apply (or set them with `defaults write com.rbatmaz69.crocus …`).
enum AppSettings {
    enum Key {
        static let hideDuringFullScreenVideo = "hideDuringFullScreenVideo"
        static let targetScreen = "targetScreen"
        static let activityPriority = "activityPriority"
        static let hoverStyle = "hoverStyle"
        static let hapticFeedback = "hapticFeedback"
        static let globalShortcut = "globalShortcut"
        /// Running timer and stopwatch (#13), so they survive a relaunch.
        static let timers = "timers"
        /// Security-scoped bookmark of the downloads folder (#18).
        static let downloadsBookmark = "downloadsBookmark"
        /// Activity and event types switched off in Settings (#27).
        static let disabledActivities = "disabledActivities"
        static let disabledEvents = "disabledEvents"
        /// Island text size: compact / standard / large (#27).
        static let textSize = "textSize"
        /// The first-launch onboarding (#26) was finished or closed.
        static let onboardingCompleted = "onboardingCompleted"
        /// Standard / Subtle / Lively (#25, UI in #27).
        static let animationStrength = "animationStrength"
        /// C5: the island flies to the other screen (UI in #27).
        static let animateScreenChange = "animateScreenChange"
        /// Debug only: storyboard timings 5× slower.
        static let debugSlowAnimations = "debugSlowAnimations"
    }

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            Key.hideDuringFullScreenVideo: true,
            Key.targetScreen: TargetScreenOption.automatic.rawValue,
            Key.hoverStyle: HoverStyle.breathe.rawValue,
            Key.hapticFeedback: true,
            Key.globalShortcut: KeyboardShortcutSpec.default.stringValue,
            Key.animateScreenChange: true,
            Key.animationStrength: MotionStrength.standard.rawValue,
        ])
    }

    static func hideDuringFullScreenVideo(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: Key.hideDuringFullScreenVideo)
    }

    static func targetScreen(in defaults: UserDefaults = .standard) -> TargetScreenOption {
        defaults.string(forKey: Key.targetScreen).flatMap(TargetScreenOption.init(rawValue:)) ?? .automatic
    }

    static func activityPriority(in defaults: UserDefaults = .standard) -> ActivityPriority {
        ActivityPriority(storedOrder: defaults.stringArray(forKey: Key.activityPriority) ?? [])
    }

    static func setActivityPriority(_ priority: ActivityPriority, in defaults: UserDefaults = .standard) {
        defaults.set(priority.storedOrder, forKey: Key.activityPriority)
    }

    static func hoverStyle(in defaults: UserDefaults = .standard) -> HoverStyle {
        defaults.string(forKey: Key.hoverStyle).flatMap(HoverStyle.init(rawValue:)) ?? .breathe
    }

    static func disabledActivities(in defaults: UserDefaults = .standard) -> Set<ActivityKind> {
        Set((defaults.stringArray(forKey: Key.disabledActivities) ?? []).compactMap(ActivityKind.init(rawValue:)))
    }

    static func setActivity(_ kind: ActivityKind, enabled: Bool, in defaults: UserDefaults = .standard) {
        var disabled = disabledActivities(in: defaults)
        if enabled { disabled.remove(kind) } else { disabled.insert(kind) }
        defaults.set(disabled.map(\.rawValue).sorted(), forKey: Key.disabledActivities)
    }

    static func disabledEvents(in defaults: UserDefaults = .standard) -> Set<EventKind> {
        Set((defaults.stringArray(forKey: Key.disabledEvents) ?? []).compactMap(EventKind.init(rawValue:)))
    }

    static func setEvents(_ kinds: Set<EventKind>, enabled: Bool, in defaults: UserDefaults = .standard) {
        var disabled = disabledEvents(in: defaults)
        if enabled { disabled.subtract(kinds) } else { disabled.formUnion(kinds) }
        defaults.set(disabled.map(\.rawValue).sorted(), forKey: Key.disabledEvents)
    }

    static func textSize(in defaults: UserDefaults = .standard) -> TextSizeAdjustment {
        defaults.string(forKey: Key.textSize).flatMap(TextSizeAdjustment.init(rawValue:)) ?? .standard
    }

    static func onboardingCompleted(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: Key.onboardingCompleted)
    }

    static func setOnboardingCompleted(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Key.onboardingCompleted)
    }

    static func animationStrength(in defaults: UserDefaults = .standard) -> MotionStrength {
        defaults.string(forKey: Key.animationStrength).flatMap(MotionStrength.init(rawValue:)) ?? .standard
    }

    static func animateScreenChange(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: Key.animateScreenChange)
    }

    static func hapticFeedback(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: Key.hapticFeedback)
    }

    /// `nil` when the user removed the shortcut (empty string).
    static func globalShortcut(in defaults: UserDefaults = .standard) -> KeyboardShortcutSpec? {
        guard let string = defaults.string(forKey: Key.globalShortcut) else { return .default }
        if string.isEmpty { return nil }
        return KeyboardShortcutSpec(string: string) ?? .default
    }
}
