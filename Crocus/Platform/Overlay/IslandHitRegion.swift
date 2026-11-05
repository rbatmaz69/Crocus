import CoreGraphics

/// The area of a panel that takes clicks; everything else passes through to
/// the apps below. For now a rectangle; the real island shapes (#5/#6) can
/// refine `contains` later.
struct IslandHitRegion: Equatable, Sendable {
    /// Island frame in screen coordinates, or `nil` while nothing is shown.
    var rect: CGRect?

    func contains(_ point: CGPoint) -> Bool {
        guard let rect, !rect.isEmpty else { return false }
        return rect.contains(point)
    }
}
