import CoreGraphics
import Testing
@testable import Crocus

@Suite struct MenuBarClearanceTests {
    // Built-in display at the origin, 179 pt notch centred.
    let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
    let notch = CGRect(x: 645.5, y: 924, width: 179, height: 32)
    var fullWingEdge: CGFloat { notch.maxX + 60 + 16 }

    func item(x: CGFloat, layer: Int = 25, y: CGFloat = 0) -> WindowInfo {
        WindowInfo(ownerPID: 7, layer: layer, bounds: CGRect(x: x, y: y, width: 30, height: 32))
    }

    func reduced(_ windows: [WindowInfo]) -> Bool {
        MenuBarClearance.isRightWingReduced(notchRect: notch, screenBounds: screen, menuBarHeight: 32, windows: windows)
    }

    @Test func noItemsKeepsFullWing() {
        #expect(!reduced([]))
    }

    @Test func distantItemsKeepFullWing() {
        #expect(!reduced([item(x: 1200), item(x: 1300)]))
        #expect(!reduced([item(x: fullWingEdge)]))
    }

    @Test func closeItemReducesWing() {
        #expect(reduced([item(x: 1300), item(x: fullWingEdge - 1)]))
    }

    @Test func otherLayersAreIgnored() {
        #expect(!reduced([item(x: notch.maxX + 10, layer: 0), item(x: notch.maxX + 10, layer: 27)]))
    }

    @Test func itemsLeftOfNotchOrOffScreenAreIgnored() {
        #expect(!reduced([item(x: 400)]))                 // left of the notch (menus side)
        #expect(!reduced([item(x: notch.maxX + 10, y: 500)])) // not in the menu bar strip
        #expect(!reduced([item(x: 1500)]))                // on the screen to the right
    }
}
