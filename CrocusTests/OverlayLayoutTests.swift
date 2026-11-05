import CoreGraphics
import Testing
@testable import Crocus

@Suite struct OverlayLayoutTests {
    static func pill(_ frame: CGRect) -> ScreenGeometry {
        .make(frame: frame, visibleFrame: frame.insetBy(dx: 0, dy: 12).offsetBy(dx: 0, dy: -12),
              safeAreaTop: 0, auxLeft: nil, auxRight: nil, isBuiltIn: false)
    }

    @Test func panelFitsLargestState() {
        let size = OverlayLayout.panelSize
        #expect(size.width >= CrocusMetrics.notch.expanded.width + 2 * OverlayLayout.margin)
        #expect(size.height >= CrocusMetrics.pill.topOffset + CrocusMetrics.pill.expanded.maxHeight)
    }

    @Test(arguments: [
        CGRect(x: 0, y: 0, width: 1470, height: 956),        // MacBook Air 15
        CGRect(x: 1470, y: 0, width: 2560, height: 1440),    // external to the right
        CGRect(x: -1920, y: -300, width: 1920, height: 1080), // external left, lower
        CGRect(x: 0, y: 956, width: 1512, height: 982),      // external above
    ])
    func panelHangsFromTopCentre(_ screen: CGRect) {
        let frame = OverlayLayout.panelFrame(for: Self.pill(screen))
        #expect(frame.maxY == screen.maxY)
        #expect(abs(frame.midX - screen.midX) <= 0.5)
        #expect(frame.size == OverlayLayout.panelSize)
    }

    @Test func panelCentresOnOffCentreNotch() {
        // Notch 4 pt right of the screen centre.
        let frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let geometry = ScreenGeometry.make(
            frame: frame, visibleFrame: frame, safeAreaTop: 38,
            auxLeft: CGRect(x: 0, y: 944, width: 667, height: 38),
            auxRight: CGRect(x: 0, y: 944, width: 659, height: 38),
            isBuiltIn: true
        )
        let panel = OverlayLayout.panelFrame(for: geometry)
        #expect(abs(panel.midX - geometry.notchRect!.midX) <= 0.5)
    }

    @Test func windowRectToScreenRect() {
        let panel = CGRect(x: 100, y: 500, width: 540, height: 306)
        // 186 × 37 at the top centre of the panel (top-left origin).
        let windowRect = CGRect(x: 177, y: 0, width: 186, height: 37)
        let screenRect = OverlayLayout.screenRect(forWindowRect: windowRect, panelFrame: panel)
        #expect(screenRect == CGRect(x: 277, y: 806 - 37, width: 186, height: 37))
    }
}
