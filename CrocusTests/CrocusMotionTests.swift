import SwiftUI
import Testing
@testable import Crocus

@Suite struct CrocusMotionC1Tests {
    typealias C1 = CrocusMotion.C1

    @Test func storyboardValues() {
        #expect(C1.contentDelay == 0.12)
        #expect(C1.contentDuration == 0.25)
        #expect(C1.contentBlur == 6)
        #expect(C1.contentScale == 0.9)
        #expect(C1.bounceDelay == 0.4)
        #expect(C1.reducedMotionFade == 0.2)
        #expect(CrocusSprings.idleToCompact == SpringSpec(response: 0.4, dampingFraction: 0.8))
    }

    @Test func contentIsInBeforeTheIslandRests() {
        // 120 + 250 = 370 ms: sharp before the 400 ms rest and the bounce.
        #expect(C1.contentDelay + C1.contentDuration < C1.bounceDelay)
    }

    /// The shape follows the spec spring: notch width 186 → 306 pt.
    /// (The storyboard's "peak 315" would need damping ≈ 0.64; the spring
    /// token wins – decided in the plan.)
    @Test func shapeSpring() {
        let spec = CrocusSprings.idleToCompact
        let spring = Spring(response: spec.response, dampingRatio: spec.dampingFraction)
        var widths: [(time: Double, width: Double)] = []
        for step in 0...1000 {
            let time = Double(step) / 1000
            widths.append((time, 186 + spring.value(target: 120.0, time: time)))
        }
        let peak = widths.max { $0.width < $1.width }!
        #expect(abs(peak.width - 307.8) < 0.2)
        #expect(abs(peak.time - 0.333) < 0.01)
        // From when on it stays within half a point of 306.
        let lastOff = widths.last { abs($0.width - 306) >= 0.5 }!
        #expect(lastOff.time < 0.5)
    }

    @Test func bouncesOnlyWhenAnActivityArrivesFromIdle() {
        #expect(CrocusMotion.bouncesOnArrival(from: .idle, to: .compact, isEvent: false, reduceMotion: false))
        #expect(!CrocusMotion.bouncesOnArrival(from: .idle, to: .compact, isEvent: true, reduceMotion: false))   // charging: C6
        #expect(!CrocusMotion.bouncesOnArrival(from: .idle, to: .compact, isEvent: false, reduceMotion: true))
        #expect(!CrocusMotion.bouncesOnArrival(from: .expanded, to: .compact, isEvent: false, reduceMotion: false))
        #expect(!CrocusMotion.bouncesOnArrival(from: .minimal, to: .compact, isEvent: false, reduceMotion: false))
    }

    @Test func slowMotionScalesTimings() {
        let defaults = UserDefaults.standard
        let before = defaults.bool(forKey: AppSettings.Key.debugSlowAnimations)
        defer { defaults.set(before, forKey: AppSettings.Key.debugSlowAnimations) }
        defaults.set(false, forKey: AppSettings.Key.debugSlowAnimations)
        #expect(CrocusMotion.seconds(0.25) == 0.25)
        defaults.set(true, forKey: AppSettings.Key.debugSlowAnimations)
        #expect(CrocusMotion.seconds(0.25) == 1.25)
    }
}

@Suite struct CrocusMotionC2Tests {
    typealias C2 = CrocusMotion.C2

    @Test func values() {
        #expect(C2.blur == 4)
        #expect(C2.compactOutScale == 1.1)
        #expect(C2.expandedInScale == 0.9)
        #expect(C2.reducedMotionFade == 0.2)
        // Calmer than the spec (0.42 / 0.72, 0.35 / 1.0) – Dynamic Island feel.
        #expect(CrocusSprings.expand == SpringSpec(response: 0.5, dampingFraction: 0.8))
        #expect(CrocusSprings.collapse == SpringSpec(response: 0.4, dampingFraction: 1))
    }

    /// Samples a spring moving `distance` points.
    func curve(_ spec: SpringSpec, distance: Double) -> [(time: Double, value: Double)] {
        let spring = Spring(response: spec.response, dampingRatio: spec.dampingFraction)
        var samples: [(time: Double, value: Double)] = []
        for step in 0...1000 {
            let time = Double(step) / 1000
            samples.append((time, spring.value(target: distance, time: time)))
        }
        return samples
    }

    @Test func expandOvershootsOnlySlightly() {
        // Height 40 → 150 (a short card).
        let samples = curve(CrocusSprings.expand, distance: 110)
        let peak = samples.max { $0.value < $1.value }!
        let overshoot = (peak.value - 110) / 110
        #expect(overshoot > 0.01 && overshoot < 0.02)
        let lastOff = samples.last { abs($0.value - 110) >= 1 }!
        #expect(lastOff.time < 0.6)
    }

    @Test func collapseNeverOvershoots() {
        let samples = curve(CrocusSprings.collapse, distance: 110)
        #expect(samples.allSatisfy { $0.value <= 110.0001 })
        let lastOff = samples.last { abs($0.value - 110) >= 1 }!
        #expect(lastOff.time < 0.45)
    }

    @MainActor @Test func hoverHintHandsOffToTheExpandSpring() {
        typealias Interaction = IslandInteractionModifier<Rectangle>
        #expect(Interaction.handOff(.expanded, reduceMotion: false) == CrocusSprings.expand.animation)
        #expect(Interaction.handOff(.compact, reduceMotion: false) == CrocusSprings.hoverHint.animation)
        #expect(Interaction.handOff(.expanded, reduceMotion: true) == nil)
    }
}
