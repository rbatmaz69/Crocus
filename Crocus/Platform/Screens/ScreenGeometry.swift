import CoreGraphics

enum IslandMode: String, Sendable {
    /// Grows out of the hardware notch of the built-in display.
    case notch
    /// Floats below the top edge of a screen without a notch.
    case pill
}

/// What Crocus needs to know about one screen, computed from raw `NSScreen`
/// values so it can be tested without hardware. Never hard-codes the notch:
/// its size comes from `safeAreaInsets.top` and the auxiliary top areas.
struct ScreenGeometry: Equatable, Sendable {
    /// Menu bar height used when it can't be read (hidden menu bar). On Tahoe
    /// the menu bar on screens without a notch is 24 pt.
    static let fallbackMenuBarHeight: CGFloat = 24

    let frame: CGRect
    let mode: IslandMode
    /// The hardware notch in screen coordinates (notch mode only).
    let notchRect: CGRect?
    let menuBarHeight: CGFloat

    /// - Parameters:
    ///   - frame: `NSScreen.frame`
    ///   - visibleFrame: `NSScreen.visibleFrame`
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top`
    ///   - auxLeft: `NSScreen.auxiliaryTopLeftArea`
    ///   - auxRight: `NSScreen.auxiliaryTopRightArea`
    ///   - isBuiltIn: `CGDisplayIsBuiltin`
    static func make(
        frame: CGRect,
        visibleFrame: CGRect,
        safeAreaTop: CGFloat,
        auxLeft: CGRect?,
        auxRight: CGRect?,
        isBuiltIn: Bool
    ) -> ScreenGeometry {
        if isBuiltIn, safeAreaTop > 0, let auxLeft, let auxRight {
            let notchWidth = frame.width - auxLeft.width - auxRight.width
            if notchWidth > 0 {
                let notch = CGRect(
                    x: frame.minX + auxLeft.width,
                    y: frame.maxY - safeAreaTop,
                    width: notchWidth,
                    height: safeAreaTop
                )
                return ScreenGeometry(frame: frame, mode: .notch, notchRect: notch, menuBarHeight: safeAreaTop)
            }
        }

        let menuBar = frame.maxY - visibleFrame.maxY
        return ScreenGeometry(
            frame: frame,
            mode: .pill,
            notchRect: nil,
            menuBarHeight: menuBar > 0 ? menuBar : fallbackMenuBarHeight
        )
    }

    var metrics: IslandModeMetrics {
        mode == .notch ? CrocusMetrics.notch : CrocusMetrics.pill
    }

    /// The idle island in screen coordinates: exactly the notch in notch mode,
    /// a 96 × 20 pill 6 pt below the top edge otherwise.
    var idleIslandRect: CGRect {
        if let notchRect { return notchRect }
        let idle = metrics.idle
        return CGRect(
            x: frame.midX - idle.width / 2,
            y: frame.maxY - metrics.topOffset - idle.height,
            width: idle.width,
            height: idle.height
        )
    }

    /// Horizontal centre of the island; the notch may not sit exactly at the
    /// screen's midpoint.
    var islandCenterX: CGFloat {
        notchRect?.midX ?? frame.midX
    }
}
