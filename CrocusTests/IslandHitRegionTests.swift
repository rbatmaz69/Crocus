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
