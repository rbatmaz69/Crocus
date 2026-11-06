import SwiftUI

/// The floating pill as one shape in panel coordinates – built like
/// `NotchIslandShape`: centre, width, height and corner radius are animated
/// together, so the fill, shadow, outline and the content mask all follow
/// exactly the same curve while the pill grows or shrinks. (Sized by a
/// layout frame instead, the parts were re-fitted separately and the
/// expanded content showed as a silhouette while collapsing.)
struct PillIslandShape: InsettableShape {
    var parameters: PillShapeParameters
    /// Horizontal centre of the pill in the shape's rect.
    var centerX: CGFloat
    var inset: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>> {
        get {
            AnimatablePair(centerX, AnimatablePair(parameters.width, AnimatablePair(parameters.height, parameters.cornerRadius)))
        }
        set {
            centerX = newValue.first
            parameters.width = newValue.second.first
            parameters.height = newValue.second.second.first
            parameters.cornerRadius = newValue.second.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let body = parameters.bodyRect(centerX: centerX)
            .offsetBy(dx: rect.minX, dy: rect.minY)
            .insetBy(dx: inset, dy: inset)
        guard body.width > 0, body.height > 0 else { return Path() }
        let radius = max(min(parameters.cornerRadius - inset, body.width / 2, body.height / 2), 0)
        return Path(roundedRect: body, cornerRadius: radius, style: .continuous)
    }

    func inset(by amount: CGFloat) -> PillIslandShape {
        var shape = self
        shape.inset += amount
        return shape
    }
}
