import CoreGraphics

/// The area of a panel that takes clicks; everything else passes through to
/// the apps below. The main shape plus, in the minimal state, the drop or
/// circle.
struct IslandHitRegion: Equatable, Sendable {
    /// Frames in screen coordinates; empty while nothing is shown.
    var rects: [CGRect]

    init(rects: [CGRect]) {
        self.rects = rects.filter { !$0.isEmpty }
    }

    init(rect: CGRect?) {
        self.init(rects: rect.map { [$0] } ?? [])
    }

    func contains(_ point: CGPoint) -> Bool {
        rects.contains { $0.contains(point) }
    }
}

/// The two shapes of the island in the minimal state.
enum IslandPart: Equatable, Sendable {
    /// The main shape (or the only one).
    case main
    /// The drop (notch) or circle (pill) of the second activity.
    case drop
}

extension IslandPart {
    /// Which part, if any, lies under `point`; the drop wins where they meet.
    static func part(at point: CGPoint, main: CGRect?, drop: CGRect?) -> IslandPart? {
        if let drop, drop.contains(point) { return .drop }
        if let main, main.contains(point) { return .main }
        return nil
    }
}
