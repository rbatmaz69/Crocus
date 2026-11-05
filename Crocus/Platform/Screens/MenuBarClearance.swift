import CoreGraphics

/// Decides whether the compact island's right wing has to shrink to 44 pt
/// because menu bar items sit too close to the notch.
///
/// Uses the window list (status items are windows on the status bar level);
/// only bounds are read, which needs no Screen Recording permission. x
/// coordinates are the same in AppKit and Core Graphics, so the notch rect
/// can be compared directly.
enum MenuBarClearance {
    /// `kCGStatusWindowLevel`.
    static let statusItemLayer = 25

    /// - Parameters:
    ///   - notchRect: the notch in screen coordinates
    ///   - screenBounds: the screen in Core Graphics coordinates (`CGDisplayBounds`)
    ///   - menuBarHeight: height of the menu bar strip to search in
    static func isRightWingReduced(
        notchRect: CGRect,
        screenBounds: CGRect,
        menuBarHeight: CGFloat,
        windows: [WindowInfo]
    ) -> Bool {
        let menuBar = CGRect(
            x: screenBounds.minX, y: screenBounds.minY,
            width: screenBounds.width, height: menuBarHeight
        )
        let leftmostItem = windows
            .filter { window in
                window.layer == statusItemLayer
                    && window.bounds.minX >= notchRect.maxX
                    && menuBar.contains(CGPoint(x: window.bounds.midX, y: window.bounds.midY))
            }
            .map(\.bounds.minX)
            .min()

        guard let leftmostItem else { return false }
        let fullWingEdge = notchRect.maxX + CrocusMetrics.notch.wingWidth + CrocusMetrics.Compact.menuBarItemSpacing
        return fullWingEdge > leftmostItem
    }
}
