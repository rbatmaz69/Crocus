import CoreGraphics

/// Pure geometry for the overlay panels, kept free of AppKit so it can be tested.
///
/// All screen rects use AppKit screen coordinates (origin bottom-left of the
/// primary screen, y up). Window rects from SwiftUI use the panel's content
/// coordinates (origin top-left, y down).
enum OverlayLayout {
    /// Room around the largest island for the pill shadow and the minimal drop.
    static let margin: CGFloat = 40

    /// Fixed panel size: big enough for the largest state of either mode.
    static let panelSize = CGSize(
        width: max(CrocusMetrics.notch.expanded.width, CrocusMetrics.pill.expanded.width) + 2 * margin,
        height: CrocusMetrics.pill.topOffset
            + max(CrocusMetrics.notch.expanded.maxHeight, CrocusMetrics.pill.expanded.maxHeight)
            + margin
    )

    /// The panel hangs from the top edge of the screen, centred on the island
    /// (the notch may not sit exactly at the screen's midpoint).
    static func panelFrame(for geometry: ScreenGeometry) -> CGRect {
        CGRect(
            x: (geometry.islandCenterX - panelSize.width / 2).rounded(),
            y: geometry.frame.maxY - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    /// Converts a rect in the panel's content coordinates (top-left origin)
    /// to screen coordinates.
    static func screenRect(forWindowRect rect: CGRect, panelFrame: CGRect) -> CGRect {
        CGRect(
            x: panelFrame.minX + rect.minX,
            y: panelFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}
