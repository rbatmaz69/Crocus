import CoreGraphics
import Testing
@testable import Crocus

@Suite struct TargetScreenResolverTests {
    static func screen(_ id: CGDirectDisplayID, x: CGFloat, builtIn: Bool = false) -> ScreenDescriptor {
        let frame = CGRect(x: x, y: 0, width: 1000, height: 800)
        return ScreenDescriptor(
            displayID: id,
            name: "Screen \(id)",
            isBuiltIn: builtIn,
            geometry: .make(frame: frame, visibleFrame: frame, safeAreaTop: 0, auxLeft: nil, auxRight: nil, isBuiltIn: builtIn)
        )
    }

    // Main display (external) first, MacBook to the right.
    let external = screen(1, x: 0)
    let macBook = screen(2, x: 1000, builtIn: true)
    var both: [ScreenDescriptor] { [external, macBook] }

    func resolve(
        _ option: TargetScreenOption,
        _ screens: [ScreenDescriptor],
        pointer: CGDirectDisplayID? = nil,
        menuBar: CGDirectDisplayID? = nil
    ) -> CGDirectDisplayID? {
        TargetScreenResolver.resolve(option, screens: screens, pointerScreenID: pointer, activeMenuBarScreenID: menuBar)
    }

    @Test func automaticFollowsPointer() {
        #expect(resolve(.automatic, both, pointer: 2) == 2)
        #expect(resolve(.automatic, both, pointer: 1) == 1)
    }

    @Test func automaticFallsBackToMain() {
        #expect(resolve(.automatic, both, pointer: nil) == 1)
        #expect(resolve(.automatic, both, pointer: 99) == 1) // disconnected
    }

    @Test func builtInOnly() {
        #expect(resolve(.builtInOnly, both, pointer: 1) == 2)
    }

    @Test func builtInOnlyWhenClosedUsesMain() {
        #expect(resolve(.builtInOnly, [external]) == 1)
    }

    @Test func mainDisplayIsFirstScreen() {
        #expect(resolve(.mainDisplay, both, pointer: 2, menuBar: 2) == 1)
        #expect(resolve(.mainDisplay, [macBook, external]) == 2)
    }

    @Test func activeMenuBar() {
        #expect(resolve(.activeMenuBar, both, menuBar: 2) == 2)
        #expect(resolve(.activeMenuBar, both, menuBar: nil) == 1)
        #expect(resolve(.activeMenuBar, both, menuBar: 99) == 1)
    }

    @Test func noScreens() {
        for option in TargetScreenOption.allCases {
            #expect(resolve(option, [], pointer: 1, menuBar: 1) == nil)
        }
    }

    @Test func pointerHitTesting() {
        #expect(ScreenDescriptor.screen(containing: CGPoint(x: 500, y: 400), in: both) == 1)
        #expect(ScreenDescriptor.screen(containing: CGPoint(x: 1000, y: 400), in: both) == 2) // shared edge
        #expect(ScreenDescriptor.screen(containing: CGPoint(x: 500, y: 800), in: both) == 1) // top edge
        #expect(ScreenDescriptor.screen(containing: CGPoint(x: 500, y: 900), in: both) == nil)
    }
}
