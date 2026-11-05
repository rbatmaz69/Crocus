import CoreGraphics

struct IslandShapeSpec: Equatable, Sendable {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
}

struct ExpandedShapeSpec: Equatable, Sendable {
    let width: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let cornerRadius: CGFloat
}

struct ShadowSpec: Equatable, Sendable {
    let y: CGFloat
    let blur: CGFloat
    let opacity: Double
}

/// Fixed sizes for one presentation mode. Runtime values such as the real
/// notch width and menu bar height come from `NSScreen` (#4), never from here.
struct IslandModeMetrics: Equatable, Sendable {
    /// Distance from the top screen edge.
    let topOffset: CGFloat
    let idle: IslandShapeSpec
    let compact: IslandShapeSpec
    /// Width of each wing left and right of the gap in compact.
    let wingWidth: CGFloat
    /// Width of the gap between the wings (the notch / idle pill).
    let gapWidth: CGFloat
    /// Spacing between island and the minimal drop / circle.
    let minimalSpacing: CGFloat
    /// Diameter of the minimal drop / circle.
    let minimalDiameter: CGFloat
    let expanded: ExpandedShapeSpec
    let headerHeight: CGFloat
    /// Concave shoulder radius where the island meets the top edge (notch only).
    let shoulderRadius: CGFloat?
    let shadows: [ShadowSpec]
}

/// Sizes from the spec (`design/README.md`, board 01), in points.
enum CrocusMetrics {
    static let notch = IslandModeMetrics(
        topOffset: 0,
        idle: IslandShapeSpec(width: 186, height: 37, cornerRadius: 10),
        compact: IslandShapeSpec(width: 306, height: 40, cornerRadius: 14),
        wingWidth: 60,
        gapWidth: 186,
        minimalSpacing: 6,
        minimalDiameter: 40,
        expanded: ExpandedShapeSpec(width: 460, minHeight: 150, maxHeight: 260, cornerRadius: 32),
        headerHeight: 37,
        shoulderRadius: 10,
        shadows: []
    )

    static let pill = IslandModeMetrics(
        topOffset: 6,
        idle: IslandShapeSpec(width: 96, height: 20, cornerRadius: 10),
        compact: IslandShapeSpec(width: 216, height: 30, cornerRadius: 15),
        wingWidth: 60,
        gapWidth: 96,
        minimalSpacing: 6,
        minimalDiameter: 30,
        expanded: ExpandedShapeSpec(width: 440, minHeight: 150, maxHeight: 260, cornerRadius: 30),
        headerHeight: 34,
        shoulderRadius: nil,
        shadows: [
            ShadowSpec(y: 8, blur: 24, opacity: 0.28),
            ShadowSpec(y: 1, blur: 3, opacity: 0.20),
        ]
    )

    /// Minimum hit target, even when the visible symbol is smaller.
    static let minimumHitTarget: CGFloat = 28
    /// Visible diameter of the page dots in the expanded state.
    static let pageDotDiameter: CGFloat = 6
}

/// Anatomy of the notch-mode island (boards 03, 05, 07).
extension CrocusMetrics {
    enum Compact {
        /// The compact island reaches this far below the hardware notch.
        static let extraHeightBelowNotch: CGFloat = 3
        static let symbolSize: CGFloat = 24
        /// Edge inset of the symbol in the left wing.
        static let leadingInset: CGFloat = 18
        /// Edge inset of the value in the right wing.
        static let trailingInset: CGFloat = 16
        /// Right wing width when menu bar items need the space.
        static let reducedWingWidth: CGFloat = 44
        /// Minimum distance between the island and menu bar items.
        static let menuBarItemSpacing: CGFloat = 16
    }

    enum Expanded {
        static let contentInset: CGFloat = 22
        static let rowSpacing: CGFloat = 14
        static let buttonHeight: CGFloat = 32
        static let minimumButtonHeight: CGFloat = 28
    }
}
