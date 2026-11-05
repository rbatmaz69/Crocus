import SwiftUI
import Testing
@testable import Crocus

@Suite struct MinimalLayoutTests {
    let centerX: CGFloat = 270
    let notch = CGSize(width: 179, height: 32)

    func compact(reduced: Bool = false) -> NotchShapeParameters {
        NotchIslandMetrics.parameters(for: .compact, notch: notch, rightWingReduced: reduced, expandedContentHeight: nil)
    }

    @Test func notchMainShapeStaysAsCompact() {
        let minimal = NotchIslandMetrics.parameters(for: .minimal, notch: notch, rightWingReduced: false, expandedContentHeight: nil)
        #expect(minimal == compact())
    }

    @Test func notchDropIsAsTallAsTheMainShape() {
        let main = compact()
        let drop = MinimalLayout.notchDropParameters(main: main)
        #expect(drop.height == main.height)
        #expect(drop.height == 35) // 32 pt notch + 3
        #expect(drop.width == drop.height)
        #expect(drop.shoulderRadius == 10)

        let dropRect = drop.bodyRect(centerX: MinimalLayout.notchDropCenterX(main: main, centerX: centerX))
        let mainRect = main.bodyRect(centerX: centerX)
        #expect(dropRect.minX - mainRect.maxX == 6)
        #expect(dropRect.minY == 0)
        #expect(dropRect.maxY == mainRect.maxY)
    }

    @Test func referenceNotchGivesSpecDrop() {
        let main = NotchIslandMetrics.parameters(
            for: .compact, notch: CGSize(width: 186, height: 37), rightWingReduced: false, expandedContentHeight: nil
        )
        let drop = MinimalLayout.notchDropParameters(main: main)
        #expect(drop.width == 40)
        #expect(drop.height == 40)
        #expect(drop.bottomRadius == 20)
    }

    @Test func notchDropFollowsReducedWing() {
        let full = MinimalLayout.notchDropCenterX(main: compact(), centerX: centerX)
        let reduced = MinimalLayout.notchDropCenterX(main: compact(reduced: true), centerX: centerX)
        #expect(full - reduced == 16) // 60 − 44
    }

    @Test func notchDropShapeHasShouldersAndRoundBottom() {
        let drop = MinimalLayout.notchDropParameters(main: NotchShapeParameters(
            leading: 100, trailing: 100, height: 40, bottomRadius: 14, shoulderRadius: 10
        ))
        let path = NotchIslandShape(parameters: drop, centerX: 100).path(in: CGRect(x: 0, y: 0, width: 200, height: 100))
        let bounds = path.boundingRect
        #expect(abs(bounds.width - 60) < 0.01)  // 40 + 2 × 10 shoulders
        #expect(abs(bounds.maxY - 40) < 0.01)
        #expect(path.contains(CGPoint(x: 100, y: 20)))
        #expect(path.contains(CGPoint(x: 78, y: 0.5)))      // shoulder flares at the top edge
        #expect(!path.contains(CGPoint(x: 78, y: 8)))       // cove stays empty
        #expect(!path.contains(CGPoint(x: 81, y: 39)))      // round bottom corner
    }

    @Test func pillGroupIsCentred() {
        #expect(MinimalLayout.pillGroupWidth == 252)
        #expect(MinimalLayout.pillMainOffset == -18)

        let pill = PillIslandMetrics.parameters(for: .minimal, expandedContentHeight: nil)
        let pillRect = pill.bodyRect(centerX: centerX + MinimalLayout.pillMainOffset)
        let circle = MinimalLayout.pillCircleRect(centerX: centerX)

        #expect(pillRect.width == 216)
        #expect(circle.width == 30)
        #expect(circle.height == 30)
        #expect(circle.minX - pillRect.maxX == 6)
        #expect(circle.minY == 6)
        #expect(pillRect.minY == 6)
        // Group edges symmetric around the centre.
        #expect(centerX - pillRect.minX == circle.maxX - centerX)
    }
}
