import CoreGraphics

/// Shape parameters of the floating pill.
struct PillShapeParameters: Equatable, Sendable {
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat

    /// The pill in panel coordinates. Its top edge stays fixed 6 pt below the
    /// screen edge in every state; it only grows down and sideways.
    func bodyRect(centerX: CGFloat) -> CGRect {
        CGRect(x: centerX - width / 2, y: PillIslandMetrics.topOffset, width: width, height: height)
    }
}

/// Sizes per state from the spec (board 04): idle 96 × 20 r 10, compact
/// 216 × 30 r 15, expanded 440 × 150–260 r 30.
enum PillIslandMetrics {
    static var topOffset: CGFloat { CrocusMetrics.pill.topOffset }

    static func parameters(for presentation: IslandPresentation, expandedContentHeight: CGFloat?) -> PillShapeParameters {
        let spec = CrocusMetrics.pill
        switch presentation {
        case .idle:
            return PillShapeParameters(width: spec.idle.width, height: spec.idle.height, cornerRadius: spec.idle.cornerRadius)
        case .compact:
            return PillShapeParameters(width: spec.compact.width, height: spec.compact.height, cornerRadius: spec.compact.cornerRadius)
        case .expanded:
            return PillShapeParameters(
                width: spec.expanded.width,
                height: NotchIslandMetrics.expandedHeight(contentHeight: expandedContentHeight),
                cornerRadius: spec.expanded.cornerRadius
            )
        }
    }
}
