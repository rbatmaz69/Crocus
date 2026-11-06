import CoreGraphics

/// Shape parameters of the floating pill.
struct PillShapeParameters: Equatable, Sendable {
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat
    /// Top edge below the screen edge: idle and compact sit centred in the
    /// menu bar; expanded grows down from the compact top.
    var top: CGFloat = 0

    /// The pill in panel coordinates.
    func bodyRect(centerX: CGFloat) -> CGRect {
        CGRect(x: centerX - width / 2, y: top, width: width, height: height)
    }
}

/// Sizes per state from the spec (board 04): idle 96 × 20 r 10, compact
/// 216 × 30 r 15, expanded 440 × 150–260 r 30.
enum PillIslandMetrics {
    static var topOffset: CGFloat { CrocusMetrics.pill.topOffset }

    /// Top edge that centres a shape of `height` in the menu bar.
    static func centredTop(height: CGFloat, menuBarHeight: CGFloat) -> CGFloat {
        max(((menuBarHeight - height) / 2).rounded(), 1)
    }

    static func parameters(for presentation: IslandPresentation, expandedContentHeight: CGFloat?, menuBarHeight: CGFloat = 30) -> PillShapeParameters {
        let spec = CrocusMetrics.pill
        let compactTop = centredTop(height: spec.compact.height, menuBarHeight: menuBarHeight)
        switch presentation {
        case .idle:
            return PillShapeParameters(width: spec.idle.width, height: spec.idle.height, cornerRadius: spec.idle.cornerRadius,
                                       top: centredTop(height: spec.idle.height, menuBarHeight: menuBarHeight))
        case .compact, .minimal:
            return PillShapeParameters(width: spec.compact.width, height: spec.compact.height, cornerRadius: spec.compact.cornerRadius, top: compactTop)
        case .expanded:
            return PillShapeParameters(
                width: spec.expanded.width,
                height: NotchIslandMetrics.expandedHeight(contentHeight: expandedContentHeight),
                cornerRadius: spec.expanded.cornerRadius,
                top: compactTop
            )
        }
    }
}
