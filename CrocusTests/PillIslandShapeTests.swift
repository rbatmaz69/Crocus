import SwiftUI
import Testing
@testable import Crocus

@Suite struct PillIslandShapeTests {
    let compact = PillShapeParameters(width: 216, height: 30, cornerRadius: 15)

    @Test func drawsThePillInPanelCoordinates() {
        let shape = PillIslandShape(parameters: compact, centerX: 260)
        let bounds = shape.path(in: CGRect(x: 0, y: 0, width: 520, height: 306)).boundingRect
        #expect(bounds == compact.bodyRect(centerX: 260))
    }

    @Test func insetForTheOutline() {
        let shape = PillIslandShape(parameters: compact, centerX: 260).inset(by: 0.5)
        let bounds = shape.path(in: CGRect(x: 0, y: 0, width: 520, height: 306)).boundingRect
        #expect(bounds == compact.bodyRect(centerX: 260).insetBy(dx: 0.5, dy: 0.5))
    }

    @Test func centreAndSizeAnimateTogether() {
        var shape = PillIslandShape(parameters: compact, centerX: 260)
        let expanded = PillIslandShape(parameters: PillShapeParameters(width: 440, height: 160, cornerRadius: 30), centerX: 240)
        var halfway = shape.animatableData
        halfway.scale(by: 0.5)
        var other = expanded.animatableData
        other.scale(by: 0.5)
        shape.animatableData = halfway + other
        #expect(shape.centerX == 250)
        #expect(shape.parameters == PillShapeParameters(width: 328, height: 95, cornerRadius: 22.5))
    }

    @Test func emptyWhileCollapsedToNothing() {
        let shape = PillIslandShape(parameters: PillShapeParameters(width: 0, height: 0, cornerRadius: 0), centerX: 100)
        #expect(shape.path(in: CGRect(x: 0, y: 0, width: 200, height: 100)).isEmpty)
    }
}
