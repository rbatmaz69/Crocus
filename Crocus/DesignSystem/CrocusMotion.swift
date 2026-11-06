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
    }

    /// C2 – compact ⇄ expanded, made to feel like the iPhone's Dynamic
    /// Island: **one motion**. Shape and content follow the same spring –
    /// the compact content grows with the island and dissolves while the
    /// expanded content grows out of its top edge and sharpens; collapsing
    /// runs the same in reverse. (The storyboard sequenced it – content out,
    /// shape, rows staggered from 380 ms – which felt stepped and late,
    /// though no frames dropped: measured.)
    enum C2 {
        /// Content dissolving or appearing during the morph.
        static let blur: CGFloat = 4
        /// Compact content grows with the island while it dissolves.
        static let compactOutScale: CGFloat = 1.1
        /// Expanded content grows out of the top edge from this.
        static let expandedInScale: CGFloat = 0.9
        /// Reduce Motion: the panel fades in/out at its final size.
        static let reducedMotionFade = 0.20
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
    var anchor: UnitPoint = .center

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: anchor)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

extension AnyTransition {
    /// Compact content.
    /// - In from idle (C1): 120 ms after the shape starts, 250 ms easeOut,
    ///   blur 6 → 0, scale 0.9 → 1 – on its own, the island grows first.
    /// - In from expanded (C2): with the collapse spring – shrinks from
    ///   1.1× into place while it sharpens, as the island closes around it.
    /// - Out: with the expand spring – grows with the island and dissolves.
    /// Reduce Motion: 200 ms cross-fade.
    @MainActor
    static func islandCompactContent(reduceMotion: Bool, fromExpanded: Bool) -> AnyTransition {
        typealias C1 = CrocusMotion.C1
        typealias C2 = CrocusMotion.C2
        if reduceMotion {
            return .opacity.animation(.easeInOut(duration: CrocusMotion.seconds(C1.reducedMotionFade)))
        }
        let identity = IslandContentEntrance(opacity: 1, blur: 0, scale: 1, anchor: .top)
        let dissolved = IslandContentEntrance(opacity: 0, blur: C2.blur, scale: C2.compactOutScale, anchor: .top)
        let insertion: AnyTransition = fromExpanded
            ? AnyTransition.modifier(active: dissolved, identity: identity)
                .animation(CrocusSprings.collapse.animation)
            : AnyTransition.modifier(
                active: IslandContentEntrance(opacity: 0, blur: C1.contentBlur, scale: C1.contentScale),
                identity: IslandContentEntrance(opacity: 1, blur: 0, scale: 1)
            )
            .animation(.easeOut(duration: CrocusMotion.seconds(C1.contentDuration)).delay(CrocusMotion.seconds(C1.contentDelay)))
        let removal = AnyTransition.modifier(active: dissolved, identity: identity)
            .animation(CrocusSprings.expand.animation)
        return .asymmetric(insertion: insertion, removal: removal)
    }

    /// Expanded content (C2): grows out of the island's top edge from 0.9×
    /// and sharpens with the expand spring; collapsing, it shrinks back and
    /// dissolves with the collapse spring – always clipped to the shape.
    /// Reduce Motion: 200 ms fade.
    static func islandExpandedContent(reduceMotion: Bool) -> AnyTransition {
        typealias C2 = CrocusMotion.C2
        if reduceMotion {
            return .opacity.animation(.easeInOut(duration: CrocusMotion.seconds(C2.reducedMotionFade)))
        }
        let hidden = IslandContentEntrance(opacity: 0, blur: C2.blur, scale: C2.expandedInScale, anchor: .top)
        let identity = IslandContentEntrance(opacity: 1, blur: 0, scale: 1, anchor: .top)
        return .asymmetric(
            insertion: AnyTransition.modifier(active: hidden, identity: identity).animation(CrocusSprings.expand.animation),
            removal: AnyTransition.modifier(active: hidden, identity: identity).animation(CrocusSprings.collapse.animation)
        )
    }
}
