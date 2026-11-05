import CoreGraphics
import Testing
@testable import Crocus

@Suite struct NotchIslandMetricsTests {
    static let referenceNotch = CGSize(width: 186, height: 37)
    static let macBookAirNotch = CGSize(width: 179, height: 32)

    func params(
        _ presentation: IslandPresentation,
        notch: CGSize = referenceNotch,
        reduced: Bool = false,
        content: CGFloat? = nil
    ) -> NotchShapeParameters {
        NotchIslandMetrics.parameters(
            for: presentation, notch: notch, rightWingReduced: reduced, expandedContentHeight: content
        )
    }

    @Test(arguments: [referenceNotch, macBookAirNotch])
    func idleMatchesNotchExactly(_ notch: CGSize) {
        let p = params(.idle, notch: notch)
        #expect(p.width == notch.width)
        #expect(p.leading == p.trailing)
        #expect(p.height == notch.height)
        #expect(p.bottomRadius == 10)
        #expect(p.shoulderRadius == 10)
    }

    @Test func compactMatchesSpecForReferenceNotch() {
        let p = params(.compact)
        #expect(p.width == 306)
        #expect(p.height == 40)
        #expect(p.bottomRadius == 14)
    }

    @Test func compactKeepsWingsOnOtherNotch() {
        let p = params(.compact, notch: Self.macBookAirNotch)
        #expect(p.width == 299) // 179 + 2 × 60
        #expect(p.height == 35)
    }

    @Test func reducedRightWing() {
        let p = params(.compact, reduced: true)
        #expect(p.leading == 153) // 93 + 60
        #expect(p.trailing == 137) // 93 + 44
    }

    @Test func expandedWidthAndRadius() {
        let p = params(.expanded, content: 200)
        #expect(p.width == 460)
        #expect(p.leading == p.trailing)
        #expect(p.height == 200)
        #expect(p.bottomRadius == 32)
    }

    @Test(arguments: [
        (nil, 150.0), (90.0, 150.0), (150.0, 150.0), (210.5, 210.5), (260.0, 260.0), (400.0, 260.0),
    ] as [(CGFloat?, CGFloat)])
    func expandedHeightIsClamped(content: CGFloat?, expected: CGFloat) {
        #expect(NotchIslandMetrics.expandedHeight(contentHeight: content) == expected)
    }

    @Test func bodyRect() {
        let p = params(.compact, reduced: true)
        #expect(p.bodyRect(centerX: 270) == CGRect(x: 270 - 153, y: 0, width: 153 + 137, height: 40))
    }
}
