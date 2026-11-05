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

    /// The panel is centred horizontally and hangs from the top edge of the screen.
    static func panelFrame(for screenFrame: CGRect) -> CGRect {
        CGRect(
            x: (screenFrame.midX - panelSize.width / 2).rounded(),
            y: screenFrame.maxY - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    /// The fixed metrics for a screen: notch mode if it has a notch, pill mode otherwise.
    static func metrics(hasNotch: Bool) -> IslandModeMetrics {
        hasNotch ? CrocusMetrics.notch : CrocusMetrics.pill
    }

    /// Where the idle island sits on a screen, in screen coordinates.
    static func idleIslandRect(in screenFrame: CGRect, hasNotch: Bool) -> CGRect {
        let metrics = metrics(hasNotch: hasNotch)
        let size = metrics.idle
        return CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - metrics.topOffset - size.height,
            width: size.width,
            height: size.height
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
