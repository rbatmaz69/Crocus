import CoreGraphics
import Testing
@testable import Crocus

/// A built-in display with a notch, described by its notch size; the aux
/// areas are derived so the notch is centred. Values are representative,
/// not taken from specific hardware: the point is that the notch always
/// comes from the aux areas.
struct NotchConfig: Sendable, CustomTestStringConvertible {
    let name: String
    let screen: CGSize
    let notch: CGSize

    var testDescription: String { name }

    var frame: CGRect { CGRect(origin: .zero, size: screen) }
    var auxWidth: CGFloat { (screen.width - notch.width) / 2 }

    func geometry(isBuiltIn: Bool = true) -> ScreenGeometry {
        let aux = CGRect(x: 0, y: screen.height - notch.height, width: auxWidth, height: notch.height)
        return .make(
            frame: frame,
            visibleFrame: CGRect(x: 0, y: 0, width: screen.width, height: screen.height - notch.height),
            safeAreaTop: notch.height,
            auxLeft: aux,
            auxRight: aux,
            isBuiltIn: isBuiltIn
        )
    }
}

@Suite struct ScreenGeometryTests {
    static let configs: [NotchConfig] = [
        NotchConfig(name: "MacBook Air 13, default", screen: CGSize(width: 1470, height: 956), notch: CGSize(width: 186, height: 37)),
        NotchConfig(name: "MacBook Air 13, more space", screen: CGSize(width: 1710, height: 1112), notch: CGSize(width: 160, height: 32)),
        NotchConfig(name: "MacBook Air 15, default", screen: CGSize(width: 1710, height: 1112), notch: CGSize(width: 186, height: 37)),
        NotchConfig(name: "MacBook Pro 14, default", screen: CGSize(width: 1512, height: 982), notch: CGSize(width: 190, height: 38)),
        NotchConfig(name: "MacBook Pro 14, larger text", screen: CGSize(width: 1352, height: 878), notch: CGSize(width: 212, height: 42)),
        NotchConfig(name: "MacBook Pro 16, default", screen: CGSize(width: 1728, height: 1117), notch: CGSize(width: 190, height: 38)),
    ]

    @Test(arguments: configs)
    func notchSizeComesFromAuxAreas(_ config: NotchConfig) throws {
        let geometry = config.geometry()
        #expect(geometry.mode == .notch)
        let notch = try #require(geometry.notchRect)
        #expect(notch.size == config.notch)
        #expect(notch.minX == config.auxWidth)
        #expect(notch.maxY == config.screen.height)
        #expect(geometry.menuBarHeight == config.notch.height)
        #expect(geometry.idleIslandRect == notch)
        #expect(geometry.islandCenterX == config.screen.width / 2)
    }

    @Test func notchOnScreenWithOffsetOrigin() throws {
        let frame = CGRect(x: -1470, y: 200, width: 1470, height: 956)
        let aux = CGRect(x: 0, y: 0, width: 642, height: 37)
        let geometry = ScreenGeometry.make(
            frame: frame, visibleFrame: frame, safeAreaTop: 37, auxLeft: aux, auxRight: aux, isBuiltIn: true
        )
        #expect(geometry.notchRect == CGRect(x: -1470 + 642, y: 200 + 956 - 37, width: 186, height: 37))
    }

    @Test func externalDisplayIsPill() {
        let frame = CGRect(x: 0, y: 0, width: 3008, height: 1692)
        let geometry = ScreenGeometry.make(
            frame: frame,
            visibleFrame: CGRect(x: 0, y: 0, width: 3008, height: 1668),
            safeAreaTop: 0, auxLeft: nil, auxRight: nil, isBuiltIn: false
        )
        #expect(geometry.mode == .pill)
        #expect(geometry.notchRect == nil)
        #expect(geometry.menuBarHeight == 24)
        #expect(geometry.idleIslandRect == CGRect(x: 1504 - 48, y: 1692 - 6 - 20, width: 96, height: 20))
    }

    @Test func externalDisplayReportingSafeAreaIsStillPill() {
        // Only the built-in display can have a hardware notch.
        let geometry = NotchConfig(name: "fake", screen: CGSize(width: 1920, height: 1080), notch: CGSize(width: 200, height: 30))
            .geometry(isBuiltIn: false)
        #expect(geometry.mode == .pill)
    }

    @Test func builtInWithoutNotchIsPill() {
        let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let geometry = ScreenGeometry.make(
            frame: frame,
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875),
            safeAreaTop: 0, auxLeft: nil, auxRight: nil, isBuiltIn: true
        )
        #expect(geometry.mode == .pill)
        #expect(geometry.menuBarHeight == 25)
    }

    @Test func hiddenMenuBarFallsBackTo24() {
        let frame = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let geometry = ScreenGeometry.make(
            frame: frame, visibleFrame: frame, safeAreaTop: 0, auxLeft: nil, auxRight: nil, isBuiltIn: false
        )
        #expect(geometry.menuBarHeight == ScreenGeometry.fallbackMenuBarHeight)
    }
}
