import CoreGraphics
import Testing
@testable import Crocus

@Suite struct HoverHintTests {
    func scale(_ style: HoverStyle, hovered: Bool = true, _ presentation: IslandPresentation = .compact, breath: Bool = false) -> CGFloat {
        HoverHint.scale(style: style, isHovered: hovered, presentation: presentation, breathPhase: breath)
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
        #expect(scale(.breathe, breath: true) == 1.015)
        #expect(HoverHint.breathes(style: .breathe, isHovered: true, presentation: .minimal))
        #expect(HoverHint.breathPeriod == 2.4)
    }

    @Test func pressFeedback() {
        #expect(HoverHint.pressedScale == 0.98)
        #expect(HoverHint.minimumPressDuration == 0.08)
    }
}
