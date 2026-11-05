import SwiftUI

extension Path {
    /// How far a continuous corner reaches along each edge, relative to its radius.
    static let continuousCornerExtent: CGFloat = 1.28
    /// Position of the control points between the edge start (0) and the
    /// corner point (1). Higher than a circle's 0.55 for a smoother,
    /// squircle-like curvature like `RoundedRectangle(style: .continuous)`.
    private static let continuousCornerControl: CGFloat = 0.64

    /// Adds a smooth corner from `start` to `end`, bending towards `corner`.
    /// The path must currently be at `start`.
    mutating func addContinuousCorner(from start: CGPoint, corner: CGPoint, to end: CGPoint) {
        let c = Self.continuousCornerControl
        let control1 = CGPoint(x: start.x + (corner.x - start.x) * c, y: start.y + (corner.y - start.y) * c)
        let control2 = CGPoint(x: end.x + (corner.x - end.x) * c, y: end.y + (corner.y - end.y) * c)
        addCurve(to: end, control1: control1, control2: control2)
    }
}
