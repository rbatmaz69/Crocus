import CoreGraphics

/// How the island reacts to the pointer. Hover never opens the island; it
/// only hints that it can be clicked.
enum HoverStyle: String, CaseIterable, Identifiable, Sendable {
    /// 1.03× and slow breathing (2.4 s period). Default.
    case breathe
    /// 1.03× only.
    case enlarge
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breathe: "Breathe"
        case .enlarge: "Enlarge"
        case .off: "Off"
        }
    }
}

enum HoverHint {
    static var enlargedScale: CGFloat { CrocusSprings.hoverScale }
    /// Breathing swings between 1.03 and this.
    static let breathLowScale: CGFloat = 1.015
    /// Full breathing cycle.
    static let breathPeriod: Double = 2.4
    /// Press feedback.
    static let pressedScale: CGFloat = 0.98
    static let minimumPressDuration: Double = 0.08

    /// Only compact and minimal can be opened, so only they hint.
    static func isActive(style: HoverStyle, isHovered: Bool, presentation: IslandPresentation) -> Bool {
        style != .off && isHovered && (presentation == .compact || presentation == .minimal)
    }

    static func breathes(style: HoverStyle, isHovered: Bool, presentation: IslandPresentation) -> Bool {
        style == .breathe && isActive(style: style, isHovered: isHovered, presentation: presentation)
    }

    /// Combined scale for the hint; `breathPhase` is the low point of the
    /// breathing cycle.
    static func scale(style: HoverStyle, isHovered: Bool, presentation: IslandPresentation, breathPhase: Bool) -> CGFloat {
        guard isActive(style: style, isHovered: isHovered, presentation: presentation) else { return 1 }
        if style == .breathe, breathPhase { return breathLowScale }
        return enlargedScale
    }
}
