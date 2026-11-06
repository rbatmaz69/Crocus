import CoreGraphics

/// Geometry of the minimal state: the main shape plus the second activity as
/// a drop (notch) or circle (pill), in panel coordinates.
///
/// Notch: the main shape stays exactly where it is in compact (nothing moves
/// in front of the camera); the square drop hangs 6 pt to its right with its
/// own shoulders, exactly as tall as the main shape (40 × 40 for the 37 pt
/// reference notch, so its bottom lines up with the island on any notch). Pill: the whole group (216 + 6 + 30 = 252) stays centred,
/// so the pill moves 18 pt to the left.
enum MinimalLayout {
    static var spacing: CGFloat { CrocusMetrics.notch.minimalSpacing }

    // MARK: Notch

    /// Spec size of the drop (reference notch); used as the upper bound when
    /// reserving room next to menu bar items.
    static var notchDropDiameter: CGFloat { CrocusMetrics.notch.minimalDiameter }

    /// The drop reuses `NotchIslandShape`: its shoulders and radius clamping
    /// give the drop its shape. Square, as tall as the main shape.
    static func notchDropParameters(main: NotchShapeParameters) -> NotchShapeParameters {
        let size = main.height
        return NotchShapeParameters(
            leading: size / 2, trailing: size / 2, height: size,
            bottomRadius: size / 2, shoulderRadius: CrocusMetrics.notch.shoulderRadius ?? 0
        )
    }

    /// Horizontal centre of the drop, right of the main shape.
    static func notchDropCenterX(main: NotchShapeParameters, centerX: CGFloat) -> CGFloat {
        centerX + main.trailing + spacing + main.height / 2
    }

    // MARK: Pill

    static var pillCircleDiameter: CGFloat { CrocusMetrics.pill.minimalDiameter }

    /// 216 + 6 + 30.
    static var pillGroupWidth: CGFloat { CrocusMetrics.pill.compact.width + spacing + pillCircleDiameter }

    /// How far the pill's centre moves left so the group stays centred.
    static var pillMainOffset: CGFloat { -(spacing + pillCircleDiameter) / 2 }

    /// Next to the compact pill, same top (centred in the menu bar).
    static func pillCircleRect(centerX: CGFloat, top: CGFloat) -> CGRect {
        let pillRight = centerX + pillMainOffset + CrocusMetrics.pill.compact.width / 2
        return CGRect(
            x: pillRight + spacing,
            y: top,
            width: pillCircleDiameter,
            height: pillCircleDiameter
        )
    }
}
