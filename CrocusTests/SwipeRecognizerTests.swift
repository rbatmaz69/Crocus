import CoreGraphics
import Testing
@testable import Crocus

@Suite struct SwipeRecognizerTests {
    /// Natural scrolling: deltas follow the fingers (positive y = down).
    func sample(
        _ dx: CGFloat, _ dy: CGFloat, _ phase: ScrollSample.Phase = .changed,
        precise: Bool = true, momentum: Bool = false, inverted: Bool = true
    ) -> ScrollSample {
        ScrollSample(deltaX: dx, deltaY: dy, isPrecise: precise, phase: phase, isMomentum: momentum, isDirectionInverted: inverted)
    }

    func run(_ samples: [ScrollSample]) -> [SwipeDirection] {
        var recognizer = SwipeRecognizer()
        return samples.compactMap { recognizer.handle($0) }
    }

    @Test func fourDirections() {
        #expect(run([sample(0, 10, .began), sample(0, 20)]) == [.down])
        #expect(run([sample(0, -10, .began), sample(0, -20)]) == [.up])
        #expect(run([sample(10, 0, .began), sample(20, 0)]) == [.right])
        #expect(run([sample(-10, 0, .began), sample(-20, 0)]) == [.left])
    }

    @Test func belowThresholdDoesNothing() {
        #expect(run([sample(0, 10, .began), sample(0, 13), sample(0, 0, .ended)]).isEmpty)
    }

    @Test func firesOncePerGesture() {
        #expect(run([sample(0, 30, .began), sample(0, 30), sample(0, 30), sample(0, 0, .ended)]) == [.down])
    }

    @Test func newGestureFiresAgain() {
        let gestures = [sample(0, 30, .began), sample(0, 0, .ended), sample(0, -30, .began), sample(0, 0, .ended)]
        #expect(run(gestures) == [.down, .up])
    }

    @Test func momentumIsIgnored() {
        #expect(run([sample(0, 10, .began), sample(0, 0, .ended), sample(0, 50, .other, momentum: true)]).isEmpty)
    }

    @Test func mouseWheelIsIgnored() {
        #expect(run([sample(0, 50, .began, precise: false), sample(0, 50, .changed, precise: false)]).isEmpty)
    }

    @Test func classicScrollingIsNormalised() {
        // Without natural scrolling the deltas point the other way.
        #expect(run([sample(0, -30, .began, inverted: false)]) == [.down])
        #expect(run([sample(30, 0, .began, inverted: false)]) == [.left])
    }

    @Test func dominantAxisWins() {
        #expect(run([sample(15, 25, .began)]) == [.down])
        #expect(run([sample(-26, 20, .began)]) == [.left])
    }
}

@Suite struct CardDragTests {
    @Test func dragLeftShowsNext() {
        #expect(CardDrag.direction(translation: CGSize(width: -60, height: 5)) == .left)
    }

    @Test func dragRightShowsPrevious() {
        #expect(CardDrag.direction(translation: CGSize(width: 45, height: -10)) == .right)
    }

    @Test(arguments: [
        CGSize(width: 39, height: 0),    // too short
        CGSize(width: -30, height: 2),   // too short
        CGSize(width: 50, height: 60),   // mostly vertical
        CGSize(width: 0, height: 0),     // plain click
    ])
    func noSwitch(_ translation: CGSize) {
        #expect(CardDrag.direction(translation: translation) == nil)
    }
}
