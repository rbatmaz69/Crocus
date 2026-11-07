import SwiftUI

/// A spring token. Every animation reads it through `animation` or
/// `spring`, which apply the animation strength setting (and the debug slow
/// motion) – one place for all springs.
struct SpringSpec: Equatable, Sendable {
    let response: Double
    let dampingFraction: Double

    /// As set by the user's animation strength.
    var effective: SpringSpec { MotionStrength.current.adjust(self) }

    var animation: Animation {
        let spec = effective
        return .spring(response: CrocusMotion.seconds(spec.response), dampingFraction: spec.dampingFraction)
    }

    /// For curves computed frame by frame (unscaled time).
    var spring: Spring {
        let spec = effective
        return Spring(response: spec.response, dampingRatio: spec.dampingFraction)
    }

    /// For SwiftUI animations built by hand, e.g. with an initial velocity
    /// (slow motion applied).
    var scaledSpring: Spring {
        let spec = effective
        return Spring(response: CrocusMotion.seconds(spec.response), dampingRatio: spec.dampingFraction)
    }
}

/// The animation strength setting (UI in #27, debug menu until then).
enum MotionStrength: String, CaseIterable, Identifiable, Sendable {
    case standard
    /// Calmer: damping +0.1 (at most 1), which at least halves every overshoot.
    case subtle
    /// Livelier: damping −0.06 – only for springs that bounce anyway. Those
    /// tuned to never overshoot (collapse, merge, opening from the drop, the
    /// screen flight) stay so: they were set that way from testing.
    case lively

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .subtle: "Subtle"
        case .lively: "Lively"
        }
    }

    static var current: MotionStrength { AppSettings.animationStrength() }

    func dampingFraction(for damping: Double) -> Double {
        switch self {
        case .standard: damping
        case .subtle: min(damping + 0.1, 1)
        case .lively: damping < 1 ? damping - 0.06 : damping
        }
    }

    /// Same pace (response) in every strength; only the bounce changes.
    func adjust(_ spec: SpringSpec) -> SpringSpec {
        SpringSpec(response: spec.response, dampingFraction: dampingFraction(for: spec.dampingFraction))
    }
}

/// Springs from the spec (`design/README.md`, board 01), tuned where testing
/// asked for it. All of Crocus' springs live here; the animation strength
/// is applied when they are used (`SpringSpec.animation` / `.spring`).
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
    /// C5, the island flying to another screen:
    /// - detach – calmer than the spec's 0.3 / 0.9, which pulled the
    ///   shoulders in within ≈ 50 ms
    /// - flight – critically damped, unlike the spec's 0.55 / 0.82: over a
    ///   screen's width that overshot ≈ 16 pt past the landing spot
    /// - attach – into the notch, calm enough to read as one motion
    static let screenDetach = SpringSpec(response: 0.40, dampingFraction: 1.00)
    static let screenChange = SpringSpec(response: 0.50, dampingFraction: 1.00)
    static let screenAttach = SpringSpec(response: 0.50, dampingFraction: 1.00)
    static let hoverHint = SpringSpec(response: 0.30, dampingFraction: 0.90)
    /// Onboarding page change (board 10): a horizontal push.
    static let onboardingPage = SpringSpec(response: 0.40, dampingFraction: 0.90)

    /// Scale of the island while the hover hint is shown.
    static let hoverScale: CGFloat = 1.03
}
