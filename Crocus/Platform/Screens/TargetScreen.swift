import CoreGraphics

/// Which screen shows the island (setting "Show island on", UI in #27).
enum TargetScreenOption: String, CaseIterable, Identifiable, Sendable {
    /// Follows the pointer, debounced by 1 s.
    case automatic
    /// The built-in MacBook display; the main display while it's closed.
    case builtInOnly
    /// The main display chosen in System Settings › Displays › Arrange.
    case mainDisplay
    /// The screen whose menu bar is active (differs from the main display
    /// when "Displays have separate Spaces" is on).
    case activeMenuBar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic (follows pointer)"
        case .builtInOnly: "MacBook display only"
        case .mainDisplay: "Main display"
        case .activeMenuBar: "Display with menu bar"
        }
    }
}

enum TargetScreenResolver {
    /// - Parameters:
    ///   - screens: connected screens, main display first
    ///   - pointerScreenID: the screen the pointer settled on (already debounced)
    ///   - activeMenuBarScreenID: the screen with the active menu bar (`NSScreen.main`)
    static func resolve(
        _ option: TargetScreenOption,
        screens: [ScreenDescriptor],
        pointerScreenID: CGDirectDisplayID?,
        activeMenuBarScreenID: CGDirectDisplayID?
    ) -> CGDirectDisplayID? {
        let mainID = screens.first?.displayID
        let connected = Set(screens.map(\.displayID))
        func ifConnected(_ id: CGDirectDisplayID?) -> CGDirectDisplayID? {
            id.flatMap { connected.contains($0) ? $0 : nil }
        }

        switch option {
        case .automatic:
            return ifConnected(pointerScreenID) ?? mainID
        case .builtInOnly:
            return screens.first(where: \.isBuiltIn)?.displayID ?? mainID
        case .mainDisplay:
            return mainID
        case .activeMenuBar:
            return ifConnected(activeMenuBarScreenID) ?? mainID
        }
    }
}
