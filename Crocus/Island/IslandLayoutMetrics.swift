import CoreGraphics

/// Layout measures of the island content for one mode. Both modes share the
/// same anatomy (wings, insets), so compact content sits at the same place
/// relative to the wings; only the gap, widths and header differ.
struct IslandLayoutMetrics: Equatable, Sendable {
    /// Width of the empty centre in compact (the notch, or the idle pill).
    let gapWidth: CGFloat
    let leadingWingWidth: CGFloat
    let trailingWingWidth: CGFloat
    let expandedWidth: CGFloat
    let headerHeight: CGFloat
    /// Width kept free in the middle of the expanded header (camera, or the
    /// same split for recognisability in pill mode).
    let headerGapWidth: CGFloat

    var compactWidth: CGFloat { leadingWingWidth + gapWidth + trailingWingWidth }

    static func notch(notchSize: CGSize, rightWingReduced: Bool) -> IslandLayoutMetrics {
        let spec = CrocusMetrics.notch
        return IslandLayoutMetrics(
            gapWidth: notchSize.width,
            leadingWingWidth: spec.wingWidth,
            trailingWingWidth: rightWingReduced ? CrocusMetrics.Compact.reducedWingWidth : spec.wingWidth,
            expandedWidth: spec.expanded.width,
            headerHeight: notchSize.height,
            headerGapWidth: notchSize.width
        )
    }

    static let pill: IslandLayoutMetrics = {
        let spec = CrocusMetrics.pill
        return IslandLayoutMetrics(
            gapWidth: spec.gapWidth,
            leadingWingWidth: spec.wingWidth,
            trailingWingWidth: spec.wingWidth,
            expandedWidth: spec.expanded.width,
            headerHeight: spec.headerHeight,
            headerGapWidth: spec.gapWidth
        )
    }()
}
