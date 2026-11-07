import CoreGraphics
import Foundation

/// Direction the fingers moved.
enum SwipeDirection: Equatable, Sendable {
    case up, down, left, right
}

/// One scroll event, reduced to what the recognizer needs (testable without
/// `NSEvent`).
struct ScrollSample: Equatable, Sendable {
    enum Phase: Equatable, Sendable { case began, changed, ended, cancelled, other }

    var deltaX: CGFloat
    var deltaY: CGFloat
    /// Trackpad (precise deltas) vs. mouse wheel.
    var isPrecise: Bool
    var phase: Phase
    /// Inertia after the fingers lifted.
    var isMomentum: Bool
    /// "Natural scrolling": deltas follow the content, i.e. the fingers.
    var isDirectionInverted: Bool
    /// Event time in seconds (`NSEvent.timestamp`), for the release speed.
    var time: TimeInterval = 0
}

/// Turns a two-finger trackpad gesture into at most one swipe. Sums the
/// deltas of a gesture (began … ended), decides once the dominant axis passes
/// the threshold, and ignores momentum and mouse wheels.
struct SwipeRecognizer: Sendable {
    static let threshold: CGFloat = 24

    private var x: CGFloat = 0
    private var y: CGFloat = 0
    private var fired = false

    mutating func handle(_ sample: ScrollSample) -> SwipeDirection? {
        guard sample.isPrecise, !sample.isMomentum else { return nil }

        switch sample.phase {
        case .began:
            reset()
            accumulate(sample)
        case .changed:
            accumulate(sample)
        case .ended, .cancelled:
            reset()
            return nil
        case .other:
            return nil
        }

        guard !fired, max(abs(x), abs(y)) >= Self.threshold else { return nil }
        fired = true
        if abs(y) >= abs(x) {
            return y > 0 ? .down : .up
        }
        return x > 0 ? .right : .left
    }

    /// Accumulates finger movement: positive x = right, positive y = down.
    private mutating func accumulate(_ sample: ScrollSample) {
        let sign: CGFloat = sample.isDirectionInverted ? 1 : -1
        x += sample.deltaX * sign
        y += sample.deltaY * sign
    }

    private mutating func reset() {
        x = 0
        y = 0
        fired = false
    }
}

/// Click-and-drag sideways on the expanded island (for mice without
/// two-finger swipes): switches cards like a horizontal swipe.
enum CardDrag {
    /// Horizontal distance a drag needs to switch cards.
    static let threshold: CGFloat = 40

    /// `translation` in view coordinates (positive x = right). Mostly
    /// horizontal drags past the threshold count; dragging left brings in
    /// the next card, like fingers moving left.
    static func direction(translation: CGSize) -> SwipeDirection? {
        guard abs(translation.width) >= threshold, abs(translation.width) > abs(translation.height) else { return nil }
        return translation.width < 0 ? .left : .right
    }
}

/// Which way a card step goes for each input. Keys follow reading order
/// (→ next), swipes and drags follow the content (fingers left pull the next
/// card in from the right).
enum CardNavigation {
    /// +1 = next card, -1 = previous card.
    static func step(forArrow direction: SwipeDirection) -> Int {
        switch direction {
        case .right: 1
        case .left: -1
        case .up, .down: 0
        }
    }

    static func step(forSwipe direction: SwipeDirection) -> Int {
        -step(forArrow: direction)
    }
}

/// Rules of the card swipe (storyboard C4), pure for tests. Positions are
/// card indices – 1.4 is 40 % of the way from card 1 to card 2 – and
/// translations are finger movement in points (positive = right).
enum CardSwipe {
    /// Share of a card's width the fingers must travel to switch …
    static let distanceThreshold: CGFloat = 0.30
    /// … or the speed they must lift off with (pt/s).
    static let velocityThreshold: CGFloat = 300
    /// Past the first and last card the strip follows at this factor.
    static let rubberBand: CGFloat = 0.3

    /// Where the strip is while the fingers have moved `translation` from
    /// card `index`: 1:1, rubber-banded beyond the first and last card.
    static func position(index: Int, count: Int, translation: CGFloat, width: CGFloat) -> CGFloat {
        guard width > 0, count > 0 else { return CGFloat(index) }
        let raw = CGFloat(index) - translation / width
        let last = CGFloat(count - 1)
        if raw < 0 { return raw * rubberBand }
        if raw > last { return last + (raw - last) * rubberBand }
        return raw
    }

    /// The card to settle on when the fingers lift: a fast flick decides by
    /// its direction, otherwise the distance; one card per swipe, never past
    /// the ends.
    static func target(index: Int, count: Int, translation: CGFloat, velocity: CGFloat, width: CGFloat) -> Int {
        guard width > 0, count > 0 else { return index }
        let step: Int
        if abs(velocity) >= velocityThreshold {
            step = velocity < 0 ? 1 : -1
        } else {
            let fraction = -translation / width
            step = fraction >= distanceThreshold ? 1 : fraction <= -distanceThreshold ? -1 : 0
        }
        return min(max(index + step, 0), count - 1)
    }

    /// The fingers' speed as a spring's initial velocity, which SwiftUI
    /// counts relative to the distance still to go.
    static func relativeVelocity(_ velocity: CGFloat, width: CGFloat, from: CGFloat, to: CGFloat) -> Double {
        let distance = to - from
        guard width > 0, abs(distance) > 0.001 else { return 0 }
        let cardsPerSecond = -velocity / width
        return Double(min(max(cardsPerSecond / distance, -30), 30))
    }
}

/// Follows a two-finger trackpad swipe sideways 1:1 (C4). Locks the axis
/// once the fingers have moved 6 pt; a vertical gesture is left to
/// `SwipeRecognizer` (expand / collapse). Momentum after lifting is ignored:
/// the swipe is decided when the fingers lift, with their speed over the
/// last 80 ms.
struct CardSwipeTracker: Sendable {
    static let lockDistance: CGFloat = 6
    static let velocityWindow: TimeInterval = 0.08

    enum Event: Equatable, Sendable {
        case changed(translation: CGFloat)
        case ended(translation: CGFloat, velocity: CGFloat)
    }

    private enum Axis: Sendable { case undecided, horizontal, vertical }

    private var axis = Axis.undecided
    private var x: CGFloat = 0
    private var y: CGFloat = 0
    private var history: [Point] = []

    private struct Point: Sendable {
        let time: TimeInterval
        let x: CGFloat
    }

    /// The current gesture moves the cards.
    var isTracking: Bool { axis == .horizontal }

    mutating func handle(_ sample: ScrollSample) -> Event? {
        guard sample.isPrecise, !sample.isMomentum else { return nil }

        switch sample.phase {
        case .began:
            reset()
            accumulate(sample)
        case .changed:
            accumulate(sample)
        case .ended, .cancelled:
            defer { reset() }
            guard axis == .horizontal else { return nil }
            return .ended(translation: x, velocity: velocity(at: sample.time))
        case .other:
            return nil
        }

        if axis == .undecided, max(abs(x), abs(y)) >= Self.lockDistance {
            axis = abs(x) > abs(y) ? .horizontal : .vertical
        }
        return axis == .horizontal ? .changed(translation: x) : nil
    }

    /// Finger movement: positive x = right (as in `SwipeRecognizer`).
    private mutating func accumulate(_ sample: ScrollSample) {
        let sign: CGFloat = sample.isDirectionInverted ? 1 : -1
        x += sample.deltaX * sign
        y += sample.deltaY * sign
        history.append(Point(time: sample.time, x: x))
        history.removeAll { sample.time - $0.time > Self.velocityWindow }
    }

    /// Speed over the last 80 ms before `time`; 0 if the fingers rested.
    private func velocity(at time: TimeInterval) -> CGFloat {
        let recent = history.filter { time - $0.time <= Self.velocityWindow }
        guard let first = recent.first, let last = recent.last, last.time > first.time else { return 0 }
        return (last.x - first.x) / CGFloat(last.time - first.time)
    }

    private mutating func reset() {
        axis = .undecided
        x = 0
        y = 0
        history.removeAll()
    }
}
