import SwiftUI

/// The notch-mode island: grows straight out of the hardware notch, with
/// concave shoulders where it meets the top screen edge and continuous
/// corners at the bottom. All parameters animate, so springs interpolate
/// width, height and radii together.
struct NotchIslandShape: Shape {
    var parameters: NotchShapeParameters
    /// Horizontal centre in the shape's rect – the notch, or the drop's
    /// centre. Animated too: the drop grows into the expanded island (#22).
    var centerX: CGFloat

    /// Circle approximation constant for the shoulder arcs.
    private static let circleControl: CGFloat = 0.5523

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<CGFloat, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>>
    > {
        get {
            AnimatablePair(
                AnimatablePair(parameters.leading, parameters.trailing),
                AnimatablePair(parameters.height, AnimatablePair(parameters.bottomRadius, AnimatablePair(parameters.shoulderRadius, centerX)))
            )
        }
        set {
            parameters.leading = newValue.first.first
            parameters.trailing = newValue.first.second
            parameters.height = newValue.second.first
            parameters.bottomRadius = newValue.second.second.first
            parameters.shoulderRadius = newValue.second.second.second.first
            centerX = newValue.second.second.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let x0 = rect.minX + centerX - max(parameters.leading, 0)
        let x1 = rect.minX + centerX + max(parameters.trailing, 0)
        let top = rect.minY
        let height = max(parameters.height, 0)
        let bottom = top + height
        let width = x1 - x0
        guard width > 0, height > 0 else { return Path() }

        // Clamp radii so nothing folds over while animating.
        let shoulder = min(max(parameters.shoulderRadius, 0), height / 2)
        let cornerExtent = min(
            max(parameters.bottomRadius, 0) * Path.continuousCornerExtent,
            width / 2,
            max(height - shoulder, 0)
        )
        let k = Self.circleControl

        var path = Path()
        // Left shoulder: quarter circle centred outside the body, so it is concave.
        path.move(to: CGPoint(x: x0 - shoulder, y: top))
        path.addCurve(
            to: CGPoint(x: x0, y: top + shoulder),
            control1: CGPoint(x: x0 - shoulder + k * shoulder, y: top),
            control2: CGPoint(x: x0, y: top + shoulder - k * shoulder)
        )
        // Left side and bottom-left corner.
        path.addLine(to: CGPoint(x: x0, y: bottom - cornerExtent))
        path.addContinuousCorner(
            from: CGPoint(x: x0, y: bottom - cornerExtent),
            corner: CGPoint(x: x0, y: bottom),
            to: CGPoint(x: x0 + cornerExtent, y: bottom)
        )
        // Bottom edge and bottom-right corner.
        path.addLine(to: CGPoint(x: x1 - cornerExtent, y: bottom))
        path.addContinuousCorner(
            from: CGPoint(x: x1 - cornerExtent, y: bottom),
            corner: CGPoint(x: x1, y: bottom),
            to: CGPoint(x: x1, y: bottom - cornerExtent)
        )
        // Right side and right shoulder.
        path.addLine(to: CGPoint(x: x1, y: top + shoulder))
        path.addCurve(
            to: CGPoint(x: x1 + shoulder, y: top),
            control1: CGPoint(x: x1, y: top + shoulder - k * shoulder),
            control2: CGPoint(x: x1 + shoulder - k * shoulder, y: top)
        )
        path.closeSubpath()
        return path
    }
}
