import CoreGraphics
import Testing
@testable import Crocus

@Suite struct OverlayLayoutTests {
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
        let frame = OverlayLayout.panelFrame(for: screen)
        #expect(frame.maxY == screen.maxY)
        #expect(abs(frame.midX - screen.midX) <= 0.5)
        #expect(frame.size == OverlayLayout.panelSize)
    }

    @Test func idleIslandNotch() {
        let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
        let rect = OverlayLayout.idleIslandRect(in: screen, hasNotch: true)
        #expect(rect == CGRect(x: 735 - 93, y: 956 - 37, width: 186, height: 37))
    }

    @Test func idleIslandPillFloats6ptBelowTop() {
        let screen = CGRect(x: 1470, y: 0, width: 2560, height: 1440)
        let rect = OverlayLayout.idleIslandRect(in: screen, hasNotch: false)
        #expect(rect == CGRect(x: 1470 + 1280 - 48, y: 1440 - 6 - 20, width: 96, height: 20))
    }

    @Test func windowRectToScreenRect() {
        let panel = CGRect(x: 100, y: 500, width: 540, height: 306)
        // 186 × 37 at the top centre of the panel (top-left origin).
        let windowRect = CGRect(x: 177, y: 0, width: 186, height: 37)
        let screenRect = OverlayLayout.screenRect(forWindowRect: windowRect, panelFrame: panel)
        #expect(screenRect == CGRect(x: 277, y: 806 - 37, width: 186, height: 37))
    }
}
