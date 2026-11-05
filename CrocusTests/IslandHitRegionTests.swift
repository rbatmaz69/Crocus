import CoreGraphics
import Testing
@testable import Crocus

@Suite struct IslandHitRegionTests {
    let region = IslandHitRegion(rect: CGRect(x: 100, y: 200, width: 186, height: 37))

    @Test func insideHits() {
        #expect(region.contains(CGPoint(x: 150, y: 220)))
        #expect(region.contains(CGPoint(x: 100, y: 200)))
    }

    @Test(arguments: [
        CGPoint(x: 99, y: 220),
        CGPoint(x: 286, y: 220),
        CGPoint(x: 150, y: 237),
        CGPoint(x: 150, y: 199),
    ])
    func outsidePassesThrough(_ point: CGPoint) {
        #expect(!region.contains(point))
    }

    @Test func emptyRegionNeverHits() {
        #expect(!IslandHitRegion(rect: nil).contains(.zero))
        #expect(!IslandHitRegion(rect: .zero).contains(.zero))
    }
}

@Suite struct IslandHitRegionMultiTests {
    let region = IslandHitRegion(rects: [
        CGRect(x: 0, y: 0, width: 299, height: 35),   // main shape
        CGRect(x: 305, y: 0, width: 40, height: 40),  // drop
    ])

    @Test func bothShapesHit() {
        #expect(region.contains(CGPoint(x: 100, y: 10)))
        #expect(region.contains(CGPoint(x: 320, y: 30)))
    }

    @Test func gapBetweenShapesPassesThrough() {
        #expect(!region.contains(CGPoint(x: 301, y: 10)))
    }

    @Test func emptyRectsAreDropped() {
        #expect(IslandHitRegion(rects: [.zero, CGRect(x: 0, y: 0, width: 10, height: 10)]).rects.count == 1)
    }
}

@Suite struct IslandPartTests {
    let main = CGRect(x: 0, y: 0, width: 299, height: 35)
    let drop = CGRect(x: 305, y: 0, width: 35, height: 35)

    @Test func identifiesThePartUnderThePointer() {
        #expect(IslandPart.part(at: CGPoint(x: 100, y: 10), main: main, drop: drop) == .main)
        #expect(IslandPart.part(at: CGPoint(x: 320, y: 10), main: main, drop: drop) == .drop)
        #expect(IslandPart.part(at: CGPoint(x: 302, y: 10), main: main, drop: drop) == nil)
        #expect(IslandPart.part(at: CGPoint(x: 100, y: 10), main: main, drop: nil) == .main)
    }
}
