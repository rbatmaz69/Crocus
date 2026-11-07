import SwiftUI

/// The island's outline while it flies between screens (C5), in global
/// screen coordinates (origin bottom left, y up).
struct FlightForm: Equatable, Sendable {
    var rect: CGRect
    var bottomRadius: CGFloat
    /// 0 while the island hangs from the top edge, half its height in flight.
    var topRadius: CGFloat
    /// The concave shoulders where a notch island meets the top edge.
    var shoulderRadius: CGFloat
    /// The pill's shadow and outline, 0…1.
    var shadow: CGFloat
}

/// Where the other display lies.
enum FlightDirection: Equatable, Sendable {
    case left, right, up, down

    static func between(source: CGRect, destination: CGRect) -> FlightDirection {
        if destination.minX >= source.maxX - 1 { return .right }
        if destination.maxX <= source.minX + 1 { return .left }
        return destination.midY > source.midY ? .up : .down
    }

    var isHorizontal: Bool { self == .left || self == .right }
}

/// Storyboard C5, pure and deterministic: the island detaches (shoulders
/// retract, it rounds, drops 6 pt and gains its shadow), flies along an arc
/// towards the other display – stretched up to 1.15× in its direction while
/// fast – and lands, squashed to 0.9 vertically, as the destination's
/// island. Both overlay windows draw the same path in global coordinates,
/// so the handover at the screen edge is seamless. Times are unscaled
/// seconds (the slow-motion debug factor is applied by the caller).
struct ScreenFlight: Sendable {
    let from: FlightForm
    let to: FlightForm
    /// The island hangs from the top edge (notch) at the start / at the end.
    let fromAttached: Bool
    let toAttached: Bool
    let direction: FlightDirection

    /// Detach: shoulders retract, the shape rounds and drops. Calmer than
    /// the spec's 0.3 / 0.9, which pulled the shoulders in within ≈ 50 ms.
    static let detachSpring = SpringSpec(response: 0.40, dampingFraction: 1.00)
    /// Flight along the arc. Critically damped, unlike the spec's 0.55 / 0.82:
    /// over a screen's width that overshot ≈ 16 pt past the landing spot,
    /// and holding it there made the island stop dead. Now it glides in.
    static let flightSpring = SpringSpec(response: 0.50, dampingFraction: 1.00)
    /// Into the notch: rise to the edge, flatten, grow the shoulders – no
    /// overshoot either, so nothing snaps.
    static let attachSpring = SpringSpec(response: 0.40, dampingFraction: 1.00)
    /// The landing squash (a damped impulse on this spring).
    static let landingSpring = SpringSpec(response: 0.50, dampingFraction: 0.70)

    static let detachDrop: CGFloat = 6
    static let flightStart = 0.18
    static let landingStart = 0.76
    /// The island rests in the destination window from here on.
    static let duration = 1.20
    /// The destination island shows from here; the flight's shadow and
    /// outline fade out by `duration`, so the two never double up.
    static let handover = duration - 0.06
    static let maxStretch: CGFloat = 1.15
    static let landingSquash: CGFloat = 0.9

    /// One moment of the flight: the outline plus a scale around its centre
    /// (stretch in flight, squash on landing – anchored at its top edge).
    struct Frame: Equatable, Sendable {
        var form: FlightForm
        var scaleX: CGFloat
        var scaleY: CGFloat
    }

    init(from: FlightForm, fromAttached: Bool, fromScreen: CGRect, to: FlightForm, toAttached: Bool, toScreen: CGRect) {
        self.from = from
        self.to = to
        self.fromAttached = fromAttached
        self.toAttached = toAttached
        self.direction = FlightDirection.between(source: fromScreen, destination: toScreen)
    }

    func frame(at time: Double) -> Frame {
        let detach = Self.value(Self.detachSpring, time)
        let flight = min(Self.value(Self.flightSpring, time - Self.flightStart), 1)
        let landing = Self.value(Self.attachSpring, time - Self.landingStart)

        // How much the island hangs from the top edge: fully at a notch
        // start, letting go while it detaches; growing back into the notch.
        let attached: CGFloat
        let hanging: FlightForm
        if fromAttached && flight < 0.5 {
            attached = Self.clamp(1 - detach)
            hanging = from
        } else if toAttached {
            attached = Self.clamp(landing)
            hanging = to
        } else {
            attached = 0
            hanging = from
        }
        // One after the other, each eased in and out so nothing jerks:
        // hanging, the shoulders go first (top still flat on the edge); then
        // it drops and rounds. Attaching runs the other way.
        let shoulders = Self.smoothstep(0.6, 1, attached)
        let onEdge = Self.smoothstep(0, 0.6, attached)

        // Position: along the arc between the detached start and the approach
        // point; the detach drop and the final attach blend in around it.
        let start = from.rect.center
        let end = to.rect.center
        let p0 = CGPoint(x: start.x, y: start.y - Self.detachDrop)
        let p3 = toAttached ? CGPoint(x: end.x, y: end.y - Self.detachDrop) : end
        let onArc = arc(p0, p3).point(at: flight)
        let stillAtStart = fromAttached ? Self.smoothstep(0, 0.6, Self.clamp(1 - detach)) : 1 - detach
        let atEnd = toAttached && !(fromAttached && flight < 0.5) ? onEdge : 0
        let centre = CGPoint(
            x: onArc.x + (start.x - p0.x) * stillAtStart + (end.x - p3.x) * atEnd,
            y: onArc.y + (start.y - p0.y) * stillAtStart + (end.y - p3.y) * atEnd
        )

        let width = from.rect.width + (to.rect.width - from.rect.width) * flight
        let height = from.rect.height + (to.rect.height - from.rect.height) * flight
        let floating = height / 2
        let form = FlightForm(
            rect: CGRect(x: centre.x - width / 2, y: centre.y - height / 2, width: width, height: height),
            bottomRadius: floating + (hanging.bottomRadius - floating) * onEdge,
            topRadius: floating * (1 - onEdge),
            shoulderRadius: hanging.shoulderRadius * shoulders,
            shadow: 1 - onEdge
        )

        let stretch = 1 + (Self.maxStretch - 1) * Self.flightSpeed(at: time)
        let squash = 1 - (1 - Self.landingSquash) * Self.landingBump(at: time - Self.landingStart)
        let across = 1 / stretch.squareRoot()
        return Frame(
            form: form,
            scaleX: direction.isHorizontal ? stretch : across,
            scaleY: (direction.isHorizontal ? across : stretch) * squash
        )
    }

    // MARK: - Path

    struct Arc: Sendable {
        let p0, p1, p2, p3: CGPoint

        func point(at t: CGFloat) -> CGPoint {
            let u = 1 - t
            let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
            return CGPoint(
                x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                y: a * p0.y + b * p1.y + c * p2.y + d * p3.y
            )
        }
    }

    /// A gentle arc: across the top it dips down into the screens; up or
    /// down it bows to the side.
    func arc(_ p0: CGPoint, _ p3: CGPoint) -> Arc {
        if direction.isHorizontal {
            let dx = p3.x - p0.x
            let depth = min(max(abs(dx) * 0.08, 40), 140)
            return Arc(p0: p0, p1: CGPoint(x: p0.x + dx / 3, y: p0.y - depth), p2: CGPoint(x: p3.x - dx / 3, y: p3.y - depth), p3: p3)
        }
        let dy = p3.y - p0.y
        let side = min(max(abs(dy) * 0.08, 40), 140)
        return Arc(p0: p0, p1: CGPoint(x: p0.x + side, y: p0.y + dy / 3), p2: CGPoint(x: p3.x + side, y: p3.y - dy / 3), p3: p3)
    }

    /// The destination's content, drawn inside the flying shape: it comes
    /// in while the island touches down, so it is fully there when the
    /// island takes over – no wait, no jump.
    /// The source island's content, drawn inside the shape as it leaves:
    /// it dissolves while the island detaches – one motion, no pause.
    static func sourceContentOpacity(at time: Double) -> Double {
        Double(1 - smoothstep(0, 0.14, CGFloat(time)))
    }

    /// Taking over from the source island, which fades out underneath: the
    /// flight's shadow and outline come in meanwhile (never two shadows).
    static let departure = 0.12

    static func departureFade(at time: Double) -> CGFloat {
        smoothstep(0, CGFloat(departure), CGFloat(time))
    }

    /// The flight's own shadow and outline during the handover.
    static func handoverFade(at time: Double) -> CGFloat {
        1 - smoothstep(CGFloat(handover), CGFloat(duration - 0.02), CGFloat(time))
    }

    static func contentOpacity(at time: Double) -> Double {
        Double(smoothstep(CGFloat(landingStart + 0.04), CGFloat(landingStart + 0.30), CGFloat(time)))
    }

    // MARK: - Timing

    static func clamp(_ value: CGFloat) -> CGFloat { min(max(value, 0), 1) }

    /// 0 below `edge0`, 1 above `edge1`, eased in between.
    static func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = clamp((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }

    static func value(_ spec: SpringSpec, _ time: Double) -> CGFloat {
        guard time > 0 else { return 0 }
        return CGFloat(Spring(response: spec.response, dampingRatio: spec.dampingFraction).value(target: 1.0, time: time))
    }

    /// Flight speed relative to its peak, 0…1 (0 once the arc is done).
    static func flightSpeed(at time: Double) -> CGFloat {
        let t = time - flightStart
        guard t > 0 else { return 0 }
        let h = 0.002
        let speed = (value(flightSpring, t + h) - value(flightSpring, max(t - h, 0))) / CGFloat(2 * h)
        guard value(flightSpring, t) < 1 else { return 0 }
        return min(max(speed / peakFlightSpeed, 0), 1)
    }

    private static let peakFlightSpeed: CGFloat = {
        let h = 0.002
        return stride(from: 0.0, through: 0.6, by: 0.002).map { t in
            (value(flightSpring, t + h) - value(flightSpring, max(t - h, 0))) / CGFloat(2 * h)
        }.max() ?? 1
    }()

    /// A damped impulse on the landing spring, peaking at 1 shortly after
    /// touchdown – the squash.
    static func landingBump(at t: Double) -> CGFloat {
        guard t > 0 else { return 0 }
        let omega = 2 * Double.pi / landingSpring.response
        let zeta = landingSpring.dampingFraction
        let decay = zeta * omega
        let damped = omega * (1 - zeta * zeta).squareRoot()
        func bump(_ t: Double) -> Double { exp(-decay * t) * sin(damped * t) }
        let peak = bump(atan(damped / decay) / damped)
        return CGFloat(bump(t) / peak)
    }
}

extension ScreenFlight {
    /// The island as it sits on a screen in the compact or minimal state, as
    /// a flight form in global coordinates.
    static func form(on geometry: ScreenGeometry, presentation: IslandPresentation, rightWingReduced: Bool) -> (form: FlightForm, attached: Bool) {
        let state: IslandPresentation = presentation == .minimal ? .minimal : .compact
        if let notch = geometry.notchRect {
            let parameters = NotchIslandMetrics.parameters(
                for: state, notch: notch.size, rightWingReduced: rightWingReduced, expandedContentHeight: nil
            )
            let rect = CGRect(
                x: notch.midX - parameters.leading,
                y: geometry.frame.maxY - parameters.height,
                width: parameters.width,
                height: parameters.height
            )
            return (FlightForm(rect: rect, bottomRadius: parameters.bottomRadius, topRadius: 0, shoulderRadius: parameters.shoulderRadius, shadow: 0), true)
        }
        let parameters = PillIslandMetrics.parameters(for: state, expandedContentHeight: nil, menuBarHeight: geometry.menuBarHeight)
        let centerX = geometry.frame.midX + (state == .minimal ? MinimalLayout.pillMainOffset : 0)
        let rect = CGRect(
            x: centerX - parameters.width / 2,
            y: geometry.frame.maxY - parameters.top - parameters.height,
            width: parameters.width,
            height: parameters.height
        )
        return (FlightForm(rect: rect, bottomRadius: parameters.cornerRadius, topRadius: parameters.cornerRadius, shoulderRadius: 0, shadow: 1), false)
    }

    /// Only an island with something in it flies: compact or minimal.
    /// Idle (invisible in the notch) and Reduce Motion cross-fade; the
    /// expanded island waits until it is collapsed.
    static func flies(presentation: IslandPresentation, enabled: Bool, reduceMotion: Bool) -> Bool {
        enabled && !reduceMotion && (presentation == .compact || presentation == .minimal)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
