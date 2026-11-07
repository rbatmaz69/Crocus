import CoreGraphics
import Foundation
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

@Suite struct CardNavigationTests {
    @Test func arrowsFollowReadingOrder() {
        #expect(CardNavigation.step(forArrow: .right) == 1)   // → next
        #expect(CardNavigation.step(forArrow: .left) == -1)   // ← previous
    }

    @Test func swipesFollowTheContent() {
        #expect(CardNavigation.step(forSwipe: .left) == 1)    // fingers left → next
        #expect(CardNavigation.step(forSwipe: .right) == -1)
        #expect(CardNavigation.step(forSwipe: .up) == 0)
    }
}

@Suite struct CardSwipeTests {
    let width: CGFloat = 460

    @Test func followsTheFingersOneToOne() {
        #expect(CardSwipe.position(index: 1, count: 3, translation: -230, width: width) == 1.5)
        #expect(CardSwipe.position(index: 1, count: 3, translation: 46, width: width) == 0.9)
    }

    @Test func rubberBandsPastTheEnds() {
        // 100 % past the last card → 30 %.
        #expect(abs(CardSwipe.position(index: 2, count: 3, translation: -460, width: width) - 2.3) < 1e-9)
        #expect(abs(CardSwipe.position(index: 0, count: 3, translation: 230, width: width) + 0.15) < 1e-9)
    }

    @Test func switchesAtThirtyPercent() {
        #expect(CardSwipe.target(index: 1, count: 3, translation: -138, velocity: 0, width: width) == 2)
        #expect(CardSwipe.target(index: 1, count: 3, translation: -137, velocity: 0, width: width) == 1)
        #expect(CardSwipe.target(index: 1, count: 3, translation: 138, velocity: 0, width: width) == 0)
    }

    @Test func aFlickSwitchesAtThreeHundredPointsPerSecond() {
        #expect(CardSwipe.target(index: 1, count: 3, translation: -20, velocity: -300, width: width) == 2)
        #expect(CardSwipe.target(index: 1, count: 3, translation: -20, velocity: -299, width: width) == 1)
        // Flicked back against the distance: the flick wins.
        #expect(CardSwipe.target(index: 1, count: 3, translation: -200, velocity: 400, width: width) == 0)
    }

    @Test func neverPastTheEnds() {
        #expect(CardSwipe.target(index: 2, count: 3, translation: -400, velocity: -900, width: width) == 2)
        #expect(CardSwipe.target(index: 0, count: 3, translation: 400, velocity: 900, width: width) == 0)
    }

    @Test func velocityIsRelativeToTheDistanceLeft() {
        // 0.4 of a card to go, fingers at one card per second leftwards.
        #expect(abs(CardSwipe.relativeVelocity(-460, width: width, from: 1.6, to: 2) - 2.5) < 1e-9)
        #expect(CardSwipe.relativeVelocity(-460, width: width, from: 2, to: 2) == 0)
    }
}

@Suite struct CardSwipeTrackerTests {
    func sample(_ dx: CGFloat, _ dy: CGFloat, _ phase: ScrollSample.Phase = .changed, at time: TimeInterval, momentum: Bool = false) -> ScrollSample {
        ScrollSample(deltaX: dx, deltaY: dy, isPrecise: true, phase: phase, isMomentum: momentum, isDirectionInverted: true, time: time)
    }

    @Test func tracksSidewaysOnceLocked() {
        var tracker = CardSwipeTracker()
        #expect(tracker.handle(sample(-4, 0, .began, at: 0)) == nil)
        #expect(tracker.handle(sample(-4, 1, at: 0.01)) == .changed(translation: -8))
        #expect(tracker.isTracking)
        #expect(tracker.handle(sample(-10, 0, at: 0.02)) == .changed(translation: -18))
    }

    @Test func leavesVerticalSwipesAlone() {
        var tracker = CardSwipeTracker()
        _ = tracker.handle(sample(0, 8, .began, at: 0))
        #expect(tracker.handle(sample(20, 0, at: 0.01)) == nil)
        #expect(tracker.handle(sample(0, 0, .ended, at: 0.02)) == nil)
    }

    @Test func endsWithTheLiftOffSpeed() {
        var tracker = CardSwipeTracker()
        _ = tracker.handle(sample(-10, 0, .began, at: 0))
        _ = tracker.handle(sample(-10, 0, at: 0.02))
        _ = tracker.handle(sample(-10, 0, at: 0.04))
        // 20 pt in 40 ms = 500 pt/s to the left.
        let end = tracker.handle(sample(0, 0, .ended, at: 0.04))
        guard case .ended(let translation, let velocity)? = end else {
            Issue.record("no end event")
            return
        }
        #expect(translation == -30)
        #expect(abs(velocity + 500) < 1e-6)
        #expect(!tracker.isTracking)
    }

    @Test func restingFingersLiftWithoutSpeed() {
        var tracker = CardSwipeTracker()
        _ = tracker.handle(sample(-10, 0, .began, at: 0))
        _ = tracker.handle(sample(-10, 0, at: 0.02))
        #expect(tracker.handle(sample(0, 0, .ended, at: 0.5)) == .ended(translation: -20, velocity: 0))
    }

    @Test func momentumIsIgnored() {
        var tracker = CardSwipeTracker()
        _ = tracker.handle(sample(-10, 0, .began, at: 0))
        _ = tracker.handle(sample(0, 0, .ended, at: 0.01))
        #expect(tracker.handle(sample(-40, 0, .other, at: 0.02, momentum: true)) == nil)
    }
}
