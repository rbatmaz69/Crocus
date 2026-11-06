import CoreGraphics
import Testing
@testable import Crocus

@Suite struct PillIslandMetricsTests {
    func params(_ presentation: IslandPresentation, content: CGFloat? = nil) -> PillShapeParameters {
        PillIslandMetrics.parameters(for: presentation, expandedContentHeight: content)
    }

    @Test func idle() {
        #expect(params(.idle) == PillShapeParameters(width: 80, height: 18, cornerRadius: 9, top: 6))
    }

    @Test func compact() {
        #expect(params(.compact) == PillShapeParameters(width: 200, height: 24, cornerRadius: 12, top: 3))
    }

    @Test func expanded() {
        #expect(params(.expanded, content: 200) == PillShapeParameters(width: 440, height: 200, cornerRadius: 30, top: 3))
        #expect(params(.expanded, content: 90).height == 150)
        #expect(params(.expanded, content: 400).height == 260)
        #expect(params(.expanded).height == 150)
    }

    /// Idle and compact sit centred in the menu bar (30 pt here); expanded
    /// grows down from the compact top.
    @Test(arguments: [IslandPresentation.idle, .compact])
    func centredInTheMenuBar(_ presentation: IslandPresentation) {
        let rect = params(presentation).bodyRect(centerX: 270)
        #expect(rect.midY == 15)
        #expect(rect.midX == 270)
    }

    @Test func expandedGrowsDownFromTheCompactTop() {
        #expect(params(.expanded, content: 220).bodyRect(centerX: 270).minY == params(.compact).top)
    }

    @Test func otherMenuBarHeights() {
        let compact = PillIslandMetrics.parameters(for: .compact, expandedContentHeight: nil, menuBarHeight: 24)
        #expect(compact.top == 1) // (24 − 24) / 2 = 0 → at least 1 pt
        let tall = PillIslandMetrics.parameters(for: .compact, expandedContentHeight: nil, menuBarHeight: 38)
        #expect(tall.top == 7)
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
