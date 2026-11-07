import SwiftUI

struct SpringSpec: Equatable, Sendable {
    let response: Double
    let dampingFraction: Double

    var animation: Animation {
        .spring(response: CrocusMotion.seconds(response), dampingFraction: dampingFraction)
    }
}

/// Springs from the spec (`design/README.md`, board 01). The animation
/// strength setting (Subtle / Lively) is applied on top in #25.
enum CrocusSprings {
    static let idleToCompact = SpringSpec(response: 0.40, dampingFraction: 0.80)
    /// Calmer than the spec's 0.42 / 0.72 (≈ 4 % overshoot): the floating
    /// pill bounced visibly; this overshoots ≈ 1.5 % – like the Dynamic Island.
    static let expand = SpringSpec(response: 0.50, dampingFraction: 0.80)
    /// Opening out of the drop (#22): the shape travels ≈ 3× as far as from
    /// the main island (and sideways), so the expand spring's overshoot
    /// showed as a wobble – same pace, no overshoot.
    static let expandFromDrop = SpringSpec(response: 0.50, dampingFraction: 1.00)
    /// Spec 0.35 / 1.0, a little softer; still no overshoot.
    static let collapse = SpringSpec(response: 0.40, dampingFraction: 1.00)
    static let dropDetach = SpringSpec(response: 0.35, dampingFraction: 0.70)
    /// The drop flowing back into the island (not in the spec): calm, no overshoot.
    static let dropMerge = SpringSpec(response: 0.32, dampingFraction: 1.00)
    static let cardSwipe = SpringSpec(response: 0.30, dampingFraction: 0.86)
    /// The island's height following the new card after a swipe (C4).
    static let cardHeight = SpringSpec(response: 0.40, dampingFraction: 0.85)
    static let screenChange = SpringSpec(response: 0.55, dampingFraction: 0.82)
    static let hoverHint = SpringSpec(response: 0.30, dampingFraction: 0.90)

    /// Scale of the island while the hover hint is shown.
    static let hoverScale: CGFloat = 1.03
}
