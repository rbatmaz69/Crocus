import CoreGraphics

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
