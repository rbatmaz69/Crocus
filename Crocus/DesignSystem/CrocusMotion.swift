import AppKit
import SwiftUI

/// Timings from the animation storyboards (board 09), in one place. The
/// strength setting (Subtle / Lively, #25) is applied on top later.
enum CrocusMotion {
    /// Debug menu "Slow Animations (5×)": every storyboard timing and spring
    /// 5× slower, to judge them by eye.
    static var slowFactor: Double {
        UserDefaults.standard.bool(forKey: AppSettings.Key.debugSlowAnimations) ? 5 : 1
    }

    static func seconds(_ value: Double) -> Double { value * slowFactor }

    /// System setting "Reduce motion".
    @MainActor static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// C1 – idle → compact (an activity arrives), ≈ 400 ms. The shape uses
    /// `CrocusSprings.idleToCompact`; the content comes in on its own and
    /// never morphs with the shape.
    enum C1 {
        static let contentDelay = 0.12
        static let contentDuration = 0.25
        static let contentBlur: CGFloat = 6
        static let contentScale: CGFloat = 0.9
        /// The symbol bounces once when the island has settled.
        static let bounceDelay = 0.40
        /// Reduce Motion: the shape jumps, the content cross-fades.
        static let reducedMotionFade = 0.20
        /// Content leaves first (as in C2), before the shape moves.
        static let contentOut = 0.10
    }

    /// Whether the arriving content's symbol bounces: only for an activity
    /// coming out of idle – not for events (charging bounces its bolt
    /// itself, C6), not when switching in compact, not with Reduce Motion.
    static func bouncesOnArrival(from old: IslandPresentation, to new: IslandPresentation, isEvent: Bool, reduceMotion: Bool) -> Bool {
        old == .idle && new == .compact && !isEvent && !reduceMotion
    }
}

/// Opacity, blur and scale of island content coming in (C1).
struct IslandContentEntrance: ViewModifier {
    let opacity: Double
    let blur: CGFloat
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

extension AnyTransition {
    /// Compact content: comes in 120 ms after the shape starts, in 250 ms
    /// (blur 6 → 0, scale 0.9 → 1, opacity 0 → 1), with its own animation
    /// so it never follows the shape's spring; leaves in 100 ms. With
    /// Reduce Motion a 200 ms cross-fade.
    static func islandCompactContent(reduceMotion: Bool) -> AnyTransition {
        typealias C1 = CrocusMotion.C1
        if reduceMotion {
            return .opacity.animation(.easeInOut(duration: CrocusMotion.seconds(C1.reducedMotionFade)))
        }
        let insertion = AnyTransition.modifier(
            active: IslandContentEntrance(opacity: 0, blur: C1.contentBlur, scale: C1.contentScale),
            identity: IslandContentEntrance(opacity: 1, blur: 0, scale: 1)
        )
        .animation(.easeOut(duration: CrocusMotion.seconds(C1.contentDuration)).delay(CrocusMotion.seconds(C1.contentDelay)))
        let removal = AnyTransition.opacity.animation(.easeOut(duration: CrocusMotion.seconds(C1.contentOut)))
        return .asymmetric(insertion: insertion, removal: removal)
    }
}
