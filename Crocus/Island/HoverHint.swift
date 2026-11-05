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
    /// Spec scale (1.03×) – what large shapes like the pill use.
    static var enlargedScale: CGFloat { CrocusSprings.hoverScale }
    /// Every shape grows by at least this much, so small ones (drop, circle)
    /// show the hint as clearly as the pill does.
    static let minimumGrowth: CGFloat = 4
    /// Full breathing cycle.
    static let breathPeriod: Double = 2.4
    /// Press feedback.
    static let pressedScale: CGFloat = 0.98
    static let minimumPressDuration: Double = 0.08

    /// Hover scale for a shape of the given width: 1.03×, or more for small
    /// shapes so they grow by at least `minimumGrowth`.
    static func enlargedScale(forWidth width: CGFloat) -> CGFloat {
        guard width > 0 else { return enlargedScale }
        return max(enlargedScale, 1 + minimumGrowth / width)
    }

    /// Breathing swings back to half the enlargement.
    static func breathLowScale(forWidth width: CGFloat) -> CGFloat {
        1 + (enlargedScale(forWidth: width) - 1) / 2
    }

    /// Only compact and minimal can be opened, so only they hint.
    static func isActive(style: HoverStyle, isHovered: Bool, presentation: IslandPresentation) -> Bool {
        style != .off && isHovered && (presentation == .compact || presentation == .minimal)
    }

    static func breathes(style: HoverStyle, isHovered: Bool, presentation: IslandPresentation) -> Bool {
        style == .breathe && isActive(style: style, isHovered: isHovered, presentation: presentation)
    }

    /// Extra scale on top of the enlargement at the low point of breathing.
    /// Depends only on the phase, so leaving hover animates it back to 1.
    static func breathFactor(breathPhase: Bool, width: CGFloat) -> CGFloat {
        breathPhase ? breathLowScale(forWidth: width) / enlargedScale(forWidth: width) : 1
    }

    /// Combined scale for the hint; `breathPhase` is the low point of the
    /// breathing cycle.
    static func scale(
        style: HoverStyle, isHovered: Bool, presentation: IslandPresentation, breathPhase: Bool, width: CGFloat
    ) -> CGFloat {
        guard isActive(style: style, isHovered: isHovered, presentation: presentation) else { return 1 }
        if style == .breathe, breathPhase { return breathLowScale(forWidth: width) }
        return enlargedScale(forWidth: width)
    }
}
