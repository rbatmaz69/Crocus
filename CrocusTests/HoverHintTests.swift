import CoreGraphics
import Testing
@testable import Crocus

@Suite struct HoverHintTests {
    /// Default width: the compact pill (216 pt) – large enough for the spec 1.03×.
    func scale(
        _ style: HoverStyle, hovered: Bool = true, _ presentation: IslandPresentation = .compact,
        breath: Bool = false, width: CGFloat = 216
    ) -> CGFloat {
        HoverHint.scale(style: style, isHovered: hovered, presentation: presentation, breathPhase: breath, width: width)
    }

    @Test(arguments: [IslandPresentation.idle, .expanded])
    func neverInIdleOrExpanded(_ presentation: IslandPresentation) {
        for style in HoverStyle.allCases {
            #expect(scale(style, presentation) == 1)
        }
    }

    @Test func notWithoutHover() {
        #expect(scale(.breathe, hovered: false) == 1)
        #expect(scale(.enlarge, hovered: false) == 1)
    }

    @Test func offNeverScales() {
        #expect(scale(.off) == 1)
        #expect(scale(.off, .minimal) == 1)
    }

    @Test func enlarge() {
        #expect(scale(.enlarge) == 1.03)
        #expect(scale(.enlarge, breath: true) == 1.03)
        #expect(!HoverHint.breathes(style: .enlarge, isHovered: true, presentation: .compact))
    }

    @Test func breathe() {
        #expect(scale(.breathe) == 1.03)
        #expect(abs(scale(.breathe, breath: true) - 1.015) < 0.0001)
        #expect(HoverHint.breathes(style: .breathe, isHovered: true, presentation: .minimal))
        #expect(HoverHint.breathPeriod == 2.4)
    }

    @Test func breathFactorDependsOnlyOnPhase() {
        #expect(HoverHint.breathFactor(breathPhase: false, width: 216) == 1)
        let factor = HoverHint.breathFactor(breathPhase: true, width: 216)
        #expect(abs(factor * HoverHint.enlargedScale(forWidth: 216) - HoverHint.breathLowScale(forWidth: 216)) < 0.0001)
    }

    @Test func largeShapesUseTheSpecScale() {
        #expect(HoverHint.enlargedScale(forWidth: 216) == 1.03)
        #expect(HoverHint.enlargedScale(forWidth: 299) == 1.03)
        #expect(HoverHint.enlargedScale(forWidth: 0) == 1.03)
    }

    @Test(arguments: [30.0, 35.0, 40.0, 96.0] as [CGFloat])
    func smallShapesGrowAtLeastFourPoints(width: CGFloat) {
        let growth = (HoverHint.enlargedScale(forWidth: width) - 1) * width
        #expect(growth >= 3.999)
        #expect(HoverHint.enlargedScale(forWidth: width) > 1.03)
    }

    @Test func breathingReturnsHalfway() {
        let width: CGFloat = 30
        let enlarged = HoverHint.enlargedScale(forWidth: width)
        #expect(abs(HoverHint.breathLowScale(forWidth: width) - (1 + (enlarged - 1) / 2)) < 0.0001)
    }
}
