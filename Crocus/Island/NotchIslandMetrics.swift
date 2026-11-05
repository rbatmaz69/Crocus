import CoreGraphics

/// Shape parameters of the notch island, measured from the horizontal centre
/// of the notch. The island may be asymmetric (reduced right wing), so it
/// uses `leading`/`trailing` instead of a width.
struct NotchShapeParameters: Equatable, Sendable {
    var leading: CGFloat
    var trailing: CGFloat
    var height: CGFloat
    var bottomRadius: CGFloat
    var shoulderRadius: CGFloat

    var width: CGFloat { leading + trailing }

    /// The island body (without shoulders) in panel coordinates.
    func bodyRect(centerX: CGFloat) -> CGRect {
        CGRect(x: centerX - leading, y: 0, width: width, height: height)
    }
}

/// Sizes per state, always relative to the real notch: the spec values
/// (306 = 60 + 186 + 60) describe the reference notch; on other notches the
/// wings stay 60 pt and the gap is the notch.
enum NotchIslandMetrics {
    static func parameters(
        for presentation: IslandPresentation,
        notch: CGSize,
        rightWingReduced: Bool,
        expandedContentHeight: CGFloat?
    ) -> NotchShapeParameters {
        let spec = CrocusMetrics.notch
        let shoulder = spec.shoulderRadius ?? 0
        let halfNotch = notch.width / 2

        switch presentation {
        case .idle:
            return NotchShapeParameters(
                leading: halfNotch, trailing: halfNotch, height: notch.height,
                bottomRadius: spec.idle.cornerRadius, shoulderRadius: shoulder
            )
        case .compact, .minimal:
            let rightWing = rightWingReduced ? CrocusMetrics.Compact.reducedWingWidth : spec.wingWidth
            return NotchShapeParameters(
                leading: halfNotch + spec.wingWidth,
                trailing: halfNotch + rightWing,
                height: notch.height + CrocusMetrics.Compact.extraHeightBelowNotch,
                bottomRadius: spec.compact.cornerRadius,
                shoulderRadius: shoulder
            )
        case .expanded:
            let half = spec.expanded.width / 2
            return NotchShapeParameters(
                leading: half, trailing: half,
                height: expandedHeight(contentHeight: expandedContentHeight),
                bottomRadius: spec.expanded.cornerRadius,
                shoulderRadius: shoulder
            )
        }
    }

    /// The expanded height follows the content, clamped to 150–260 pt.
    static func expandedHeight(contentHeight: CGFloat?) -> CGFloat {
        let range = CrocusMetrics.notch.expanded
        return min(max(contentHeight ?? range.minHeight, range.minHeight), range.maxHeight)
    }
}
