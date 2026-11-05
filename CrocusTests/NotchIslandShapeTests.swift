import SwiftUI
import Testing
@testable import Crocus

@Suite struct NotchIslandShapeTests {
    let rect = CGRect(x: 0, y: 0, width: 540, height: 306)
    let centerX: CGFloat = 270
    let compact = NotchShapeParameters(leading: 153, trailing: 153, height: 40, bottomRadius: 14, shoulderRadius: 10)

    func path(_ p: NotchShapeParameters) -> Path {
        NotchIslandShape(parameters: p, centerX: centerX).path(in: rect)
    }

    @Test func boundsAreBodyPlusShoulders() {
        let bounds = path(compact).boundingRect
        #expect(abs(bounds.minX - (270 - 153 - 10)) < 0.01)
        #expect(abs(bounds.maxX - (270 + 153 + 10)) < 0.01)
        #expect(abs(bounds.minY) < 0.01)
        #expect(abs(bounds.maxY - 40) < 0.01)
    }

    @Test func bodyIsFilled() {
        let p = path(compact)
        #expect(p.contains(CGPoint(x: 270, y: 20)))
        #expect(p.contains(CGPoint(x: 118, y: 20)))   // just inside the left edge
        #expect(p.contains(CGPoint(x: 422, y: 15)))   // just inside the right edge, above the corner
    }

    @Test func shouldersAreConcave() {
        let p = path(compact)
        let x0: CGFloat = 270 - 153
        let x1: CGFloat = 270 + 153
        // Near the top edge the shoulder fills outward …
        #expect(p.contains(CGPoint(x: x0 - 2, y: 0.5)))
        #expect(p.contains(CGPoint(x: x1 + 2, y: 0.5)))
        // … but the cove between shoulder and side stays empty.
        #expect(!p.contains(CGPoint(x: x0 - 2, y: 8)))
        #expect(!p.contains(CGPoint(x: x1 + 2, y: 8)))
        // Nothing beyond the shoulder radius.
        #expect(!p.contains(CGPoint(x: x0 - 11, y: 0.5)))
    }

    @Test func bottomCornersAreRounded() {
        let p = path(compact)
        #expect(!p.contains(CGPoint(x: 270 - 153 + 0.5, y: 39.5)))
        #expect(!p.contains(CGPoint(x: 270 + 153 - 0.5, y: 39.5)))
        #expect(p.contains(CGPoint(x: 270, y: 39.5)))
    }

    @Test func animatableDataRoundTrips() {
        var shape = NotchIslandShape(parameters: compact, centerX: centerX)
        let data = shape.animatableData
        shape.parameters = NotchShapeParameters(leading: 1, trailing: 2, height: 3, bottomRadius: 4, shoulderRadius: 5)
        shape.animatableData = data
        #expect(shape.parameters == compact)
    }

    @Test func interpolatesAllParameters() {
        let idle = NotchShapeParameters(leading: 93, trailing: 93, height: 37, bottomRadius: 10, shoulderRadius: 10)
        var shape = NotchIslandShape(parameters: idle, centerX: centerX)
        var data = shape.animatableData
        var delta = NotchIslandShape(parameters: compact, centerX: centerX).animatableData
        delta -= data
        delta.scale(by: 0.5)
        data += delta
        shape.animatableData = data
        #expect(shape.parameters == NotchShapeParameters(leading: 123, trailing: 123, height: 38.5, bottomRadius: 12, shoulderRadius: 10))
    }

    @Test func oversizedRadiiAreClamped() {
        let tiny = NotchShapeParameters(leading: 5, trailing: 5, height: 8, bottomRadius: 32, shoulderRadius: 10)
        let bounds = path(tiny).boundingRect
        #expect(bounds.maxY <= 8.01)
        #expect(bounds.minX >= 270 - 5 - 4.01) // shoulder clamped to half the height
        #expect(!path(tiny).isEmpty)
    }

    @Test func emptyWhenCollapsedToNothing() {
        let zero = NotchShapeParameters(leading: 0, trailing: 0, height: 0, bottomRadius: 10, shoulderRadius: 10)
        #expect(path(zero).isEmpty)
    }
}
