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
    /// Spec 0.35 / 1.0, a little softer; still no overshoot.
    static let collapse = SpringSpec(response: 0.40, dampingFraction: 1.00)
    static let dropDetach = SpringSpec(response: 0.35, dampingFraction: 0.70)
    static let cardSwipe = SpringSpec(response: 0.30, dampingFraction: 0.86)
    static let screenChange = SpringSpec(response: 0.55, dampingFraction: 0.82)
    static let hoverHint = SpringSpec(response: 0.30, dampingFraction: 0.90)

    /// Scale of the island while the hover hint is shown.
    static let hoverScale: CGFloat = 1.03
}
