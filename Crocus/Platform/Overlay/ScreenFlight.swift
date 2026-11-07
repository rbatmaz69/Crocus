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
/// fast – and docks as the destination's island: the pill flies straight
/// into its place and settles; into the notch it rises the last 6 pt while
/// its shoulders grow back. No landing squash: its rebound read as the
/// island growing again after it had arrived. Both overlay windows draw the same path in global coordinates,
/// so the handover at the screen edge is seamless. Times are unscaled
/// seconds (the slow-motion debug factor is applied by the caller).
struct ScreenFlight: Sendable {
    let from: FlightForm
    let to: FlightForm
    /// The island hangs from the top edge (notch) at the start / at the end.
    let fromAttached: Bool
    let toAttached: Bool
    let direction: FlightDirection
    /// The path from the detached start to the approach point below the
    /// destination, in global coordinates.
    let route: Route

    /// The springs (`CrocusSprings`): detach, flight along the arc, attach.
    static let detachSpring = CrocusSprings.screenDetach
    static let flightSpring = CrocusSprings.screenChange
    static let attachSpring = CrocusSprings.screenAttach
    /// Docking into the notch starts on the last stretch of the approach,
    /// not after it.
    static let attachStart = landingStart - 0.08

    static let detachDrop: CGFloat = 6
    static let flightStart = 0.18
    static let landingStart = 0.76
    /// The destination island appears under the flight from here (the same
    /// opaque image); only the shadows cross-fade, linearly, over
    /// `handoverFade` – never two, never none. The content is fully in by then.
    static let handover = landingStart + 0.30
    static let handoverFade = 0.15
    /// The flight is over (and its windows can go) from here on.
    static let duration = handover + handoverFade + 0.04
    static let maxStretch: CGFloat = 1.15

    /// One moment of the flight: the outline plus a stretch along the flight
    /// direction (anchored at its top edge).
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
        let direction = FlightDirection.between(source: fromScreen, destination: toScreen)
        self.direction = direction
        self.route = Self.route(
            from: CGPoint(x: from.rect.midX, y: from.rect.maxY - Self.detachDrop),
            to: Self.approach(to: to, attached: toAttached),
            direction: direction
        )
    }

    func frame(at time: Double) -> Frame {
        let detach = Self.value(Self.detachSpring, time)
        let flight = min(Self.value(Self.flightSpring, time - Self.flightStart), 1)
        let landing = Self.value(Self.attachSpring, time - Self.attachStart)

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

        // Position of the island's top edge (its middle): along the route
        // between the detached start and the approach point; the detach drop
        // and the final attach blend in around it. Led by the top edge, the
        // island grows and shrinks downwards – its top never bobs.
        let start = from.rect.topCenter
        let end = to.rect.topCenter
        let p0 = CGPoint(x: start.x, y: start.y - Self.detachDrop)
        let p3 = Self.approach(to: to, attached: toAttached)
        let onArc = route.point(at: flight)
        let stillAtStart = fromAttached ? Self.smoothstep(0, 0.6, Self.clamp(1 - detach)) : 1 - detach
        // Into the notch it rises the last 6 pt as it docks; the pill needs
        // no second motion – it flies straight into its place.
        let atEnd: CGFloat = toAttached && !(fromAttached && flight < 0.5) ? onEdge : 0
        let top = CGPoint(
            x: onArc.x + (start.x - p0.x) * stillAtStart + (end.x - p3.x) * atEnd,
            y: onArc.y + (start.y - p0.y) * stillAtStart + (end.y - p3.y) * atEnd
        )

        let width = from.rect.width + (to.rect.width - from.rect.width) * flight
        let height = from.rect.height + (to.rect.height - from.rect.height) * flight
        let floating = height / 2
        let form = FlightForm(
            rect: CGRect(x: top.x - width / 2, y: top.y - height, width: width, height: height),
            bottomRadius: floating + (hanging.bottomRadius - floating) * onEdge,
            topRadius: floating * (1 - onEdge),
            shoulderRadius: hanging.shoulderRadius * shoulders,
            shadow: 1 - onEdge
        )

        // Stretched along where it is actually heading – sideways, slanted
        // or straight up when the other screen's top lies much higher.
        let stretch = 1 + (Self.maxStretch - 1) * Self.flightSpeed(at: time)
        let across = 1 / stretch.squareRoot()
        let heading = route.tangent(at: flight)
        return Frame(
            form: form,
            scaleX: across + (stretch - across) * heading.dx * heading.dx,
            scaleY: across + (stretch - across) * heading.dy * heading.dy
        )
    }

    // MARK: - Path

    struct Arc: Equatable, Sendable {
        let p0, p1, p2, p3: CGPoint

        /// Unit direction of travel at `t`.
        func tangent(at t: CGFloat) -> CGVector {
            let u = 1 - t
            let dx = 3 * u * u * (p1.x - p0.x) + 6 * u * t * (p2.x - p1.x) + 3 * t * t * (p3.x - p2.x)
            let dy = 3 * u * u * (p1.y - p0.y) + 6 * u * t * (p2.y - p1.y) + 3 * t * t * (p3.y - p2.y)
            let length = (dx * dx + dy * dy).squareRoot()
            guard length > 0.0001 else { return CGVector(dx: 1, dy: 0) }
            return CGVector(dx: dx / length, dy: dy / length)
        }

        func point(at t: CGFloat) -> CGPoint {
            let u = 1 - t
            let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
            return CGPoint(
                x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                y: a * p0.y + b * p1.y + c * p2.y + d * p3.y
            )
        }
    }

    /// Cubic pieces with a share of the progress each.
    struct Route: Sendable {
        let pieces: [Arc]
        let shares: [CGFloat]

        init(_ pieces: [Arc], weights: [CGFloat]) {
            self.pieces = pieces
            let total = max(weights.reduce(0, +), 0.0001)
            self.shares = weights.map { $0 / total }
        }

        private func locate(_ progress: CGFloat) -> (Arc, CGFloat) {
            var start: CGFloat = 0
            for (piece, share) in zip(pieces, shares) {
                if progress <= start + share || piece == pieces.last {
                    return (piece, ScreenFlight.clamp((progress - start) / max(share, 0.0001)))
                }
                start += share
            }
            return (pieces[0], 0)
        }

        func point(at progress: CGFloat) -> CGPoint {
            let (piece, t) = locate(progress)
            return piece.point(at: t)
        }

        func tangent(at progress: CGFloat) -> CGVector {
            let (piece, t) = locate(progress)
            return piece.tangent(at: t)
        }
    }

    /// Where the arc ends: the pill's own place – it flies straight in and
    /// settles on one spring (a separate rise on top of the slowing arc made
    /// it bob up and down); 6 pt below the notch, which it then rises into
    /// while its shoulders grow.
    static func approach(to form: FlightForm, attached: Bool) -> CGPoint {
        CGPoint(x: form.rect.midX, y: form.rect.maxY - (attached ? detachDrop : 0))
    }

    /// One gentle arc: across the top it dips down into the screens; up or
    /// down it bows to the side.
    static func route(from p0: CGPoint, to p3: CGPoint, direction: FlightDirection) -> Route {
        if direction.isHorizontal {
            let dx = p3.x - p0.x
            let depth = min(max(abs(dx) * 0.08, 40), 140)
            return Route([Arc(p0: p0, p1: CGPoint(x: p0.x + dx / 3, y: p0.y - depth), p2: CGPoint(x: p3.x - dx / 3, y: p3.y - depth), p3: p3)], weights: [1])
        }
        let dy = p3.y - p0.y
        let side = min(max(abs(dy) * 0.08, 40), 140)
        return Route([Arc(p0: p0, p1: CGPoint(x: p0.x + side, y: p0.y + dy / 3), p2: CGPoint(x: p3.x + side, y: p3.y - dy / 3), p3: p3)], weights: [1])
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

    /// The flight's shadow and outline while the island's come in.
    static func handoverShadow(at time: Double) -> CGFloat {
        1 - clamp(CGFloat((time - handover) / handoverFade))
    }

    /// How far the destination's content has come in, 0…1: it grows in
    /// over the last 20 % of the approach, so it is there as the island
    /// arrives and docks – not after.
    static func contentProgress(at time: Double) -> CGFloat {
        smoothstep(0.80, 1.0, min(value(flightSpring, time - flightStart), 1))
    }

    /// When the content (and the destination's drop) starts to come in.
    static let contentStart: Double = stride(from: flightStart, through: duration, by: 0.002)
        .first { contentProgress(at: $0) > 0 } ?? landingStart

    // MARK: - Timing

    static func clamp(_ value: CGFloat) -> CGFloat { min(max(value, 0), 1) }

    /// 0 below `edge0`, 1 above `edge1`, eased in between.
    static func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = clamp((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }

    static func value(_ spec: SpringSpec, _ time: Double) -> CGFloat {
        guard time > 0 else { return 0 }
        return CGFloat(spec.spring.value(target: 1.0, time: time))
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
    var topCenter: CGPoint { CGPoint(x: midX, y: maxY) }
}
