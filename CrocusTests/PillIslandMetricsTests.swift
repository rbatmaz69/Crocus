import CoreGraphics
import Testing
@testable import Crocus

@Suite struct PillIslandMetricsTests {
    func params(_ presentation: IslandPresentation, content: CGFloat? = nil) -> PillShapeParameters {
        PillIslandMetrics.parameters(for: presentation, expandedContentHeight: content)
    }

    @Test func idle() {
        #expect(params(.idle) == PillShapeParameters(width: 96, height: 20, cornerRadius: 10))
    }

    @Test func compact() {
        #expect(params(.compact) == PillShapeParameters(width: 216, height: 30, cornerRadius: 15))
    }

    @Test func expanded() {
        #expect(params(.expanded, content: 200) == PillShapeParameters(width: 440, height: 200, cornerRadius: 30))
        #expect(params(.expanded, content: 90).height == 150)
        #expect(params(.expanded, content: 400).height == 260)
        #expect(params(.expanded).height == 150)
    }

    @Test(arguments: [IslandPresentation.idle, .compact, .expanded])
    func topEdgeStaysFixed(_ presentation: IslandPresentation) {
        let rect = params(presentation, content: 220).bodyRect(centerX: 270)
        #expect(rect.minY == 6)
        #expect(rect.midX == 270)
    }

    @Test func shadowRadiusIsHalfTheBlur() {
        let shadows = CrocusMetrics.pill.shadows
        #expect(shadows.map(\.radius) == [12, 1.5])
        #expect(shadows.map(\.y) == [8, 1])
    }

    @Test func outlineAdaptsToWallpaper() {
        let light = PillOutline.spec(menuBarIsDark: false)
        let dark = PillOutline.spec(menuBarIsDark: true)
        #expect(light.token.hex == 0x000000)
        #expect(light.opacity == 0.12)
        #expect(dark.token.hex == 0xFFFFFF)
        #expect(dark.opacity == 0.08)
        #expect(PillOutline.width == 0.5)
    }
}
