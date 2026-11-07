import CoreGraphics
import Testing
@testable import Crocus

@Suite struct ScreenFlightTests {
    /// MacBook on the left with a 200 pt notch, external display to its right.
    let macBook = ScreenGeometry(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        mode: .notch,
        notchRect: CGRect(x: 656, y: 950, width: 200, height: 32),
        menuBarHeight: 32
    )
    let external = ScreenGeometry(
        frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
        mode: .pill,
        notchRect: nil,
        menuBarHeight: 30
    )

    func flight(from: ScreenGeometry, to: ScreenGeometry) -> ScreenFlight {
        let start = ScreenFlight.form(on: from, presentation: .compact, rightWingReduced: false)
        let end = ScreenFlight.form(on: to, presentation: .compact, rightWingReduced: false)
        return ScreenFlight(
            from: start.form, fromAttached: start.attached, fromScreen: from.frame,
            to: end.form, toAttached: end.attached, toScreen: to.frame
        )
    }

    func samples(_ flight: ScreenFlight) -> [ScreenFlight.Frame] {
        stride(from: 0.0, through: ScreenFlight.duration, by: 0.002).map { flight.frame(at: $0) }
    }

    @Test func directionFollowsTheArrangement() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(FlightDirection.between(source: a, destination: CGRect(x: 100, y: 0, width: 100, height: 100)) == .right)
        #expect(FlightDirection.between(source: a, destination: CGRect(x: -100, y: 20, width: 100, height: 100)) == .left)
        #expect(FlightDirection.between(source: a, destination: CGRect(x: 30, y: 100, width: 100, height: 100)) == .up)
        #expect(FlightDirection.between(source: a, destination: CGRect(x: 30, y: -100, width: 100, height: 100)) == .down)
    }

    @Test func formsMatchTheIslands() {
        let notch = ScreenFlight.form(on: macBook, presentation: .compact, rightWingReduced: false)
        #expect(notch.attached)
        #expect(notch.form.rect == CGRect(x: 596, y: 947, width: 320, height: 35))
        #expect(notch.form.shoulderRadius == 10)
        let pill = ScreenFlight.form(on: external, presentation: .compact, rightWingReduced: false)
        #expect(!pill.attached)
        // 200 × 24, centred in the 30 pt menu bar (3 pt from the top).
        #expect(pill.form.rect == CGRect(x: 2692, y: 1413, width: 200, height: 24))
        #expect(pill.form.shadow == 1)
        // Minimal: the main pill sits left of centre.
        let minimal = ScreenFlight.form(on: external, presentation: .minimal, rightWingReduced: false)
        #expect(minimal.form.rect.midX == 1512 + 1280 + MinimalLayout.pillMainOffset)
    }

    @Test func startsExactlyAsTheIsland() {
        let notchToPill = flight(from: macBook, to: external)
        let first = notchToPill.frame(at: 0)
        #expect(first.form == notchToPill.from)
        #expect(first.scaleX == 1 && first.scaleY == 1)
    }

    @Test func endsExactlyAsTheDestinationIsland() {
        for flight in [flight(from: macBook, to: external), flight(from: external, to: macBook)] {
            let last = flight.frame(at: ScreenFlight.duration)
            #expect(abs(last.form.rect.minX - flight.to.rect.minX) < 0.5)
            #expect(abs(last.form.rect.minY - flight.to.rect.minY) < 0.5)
            #expect(abs(last.form.rect.width - flight.to.rect.width) < 0.5)
            #expect(abs(last.form.shoulderRadius - flight.to.shoulderRadius) < 0.5)
            #expect(abs(last.form.shadow - flight.to.shadow) < 0.05)
            #expect(abs(last.scaleY - 1) < 0.01)
        }
    }

    @Test func detachesThenDrops() {
        let flight = flight(from: macBook, to: external)
        // Detaching flows into the flight: when it sets off, the island has
        // already left the edge …
        #expect(982 - flight.frame(at: ScreenFlight.flightStart).form.rect.maxY > 2)
        // … and shortly after it is fully round, without shoulders, with shadow.
        let detached = flight.frame(at: 0.3).form
        #expect(detached.shoulderRadius < 1)
        #expect(detached.shadow > 0.9)
    }

    @Test func shouldersNeverMeetARoundedTop() {
        // Shoulders go first, then the top rounds – nothing jumps in between.
        for frame in samples(flight(from: macBook, to: external)) + samples(flight(from: external, to: macBook)) {
            #expect(frame.form.shoulderRadius < 0.01 || frame.form.topRadius < 0.01)
        }
    }

    @Test func arcsDownBetweenSideBySideScreens() {
        let flight = flight(from: macBook, to: external)
        let lowest = samples(flight).map(\.form.rect.maxY).min()!
        #expect(lowest < flight.to.rect.maxY - 20)
    }

    @Test func docksInOneMotionWithoutBobbing() {
        // The real setup too: the MacBook sits 499 pt lower than the external
        // display. Arriving, the island's top only ever rises into place –
        // no dip, no second push.
        let lower = ScreenGeometry(
            frame: CGRect(x: -1470, y: -499, width: 1470, height: 956), mode: .notch,
            notchRect: CGRect(x: -824, y: 425, width: 179, height: 32), menuBarHeight: 32
        )
        let big = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 3008, height: 1692), mode: .pill, notchRect: nil, menuBarHeight: 30)
        for flight in [flight(from: macBook, to: external), flight(from: lower, to: big)] {
            let tops = stride(from: ScreenFlight.contentStart, through: ScreenFlight.duration, by: 0.004).map {
                flight.frame(at: $0).form.rect.maxY
            }
            #expect(zip(tops, tops.dropFirst()).allSatisfy { $1 >= $0 - 0.001 })
            #expect(tops.allSatisfy { $0 <= flight.to.rect.maxY + 0.001 })
        }
    }

    @Test func glidesIntoTheLandingSpotWithoutOvershooting() {
        // Over a whole screen the old 0.55 / 0.82 spring passed the spot and
        // was held there: the island stopped dead. Now it only ever closes in.
        let flight = flight(from: macBook, to: external)
        let distances = stride(from: ScreenFlight.flightStart + 0.05, through: ScreenFlight.duration, by: 0.004).map {
            abs(flight.frame(at: $0).form.rect.midX - flight.to.rect.midX)
        }
        #expect(zip(distances, distances.dropFirst()).allSatisfy { $1 <= $0 + 0.001 })
    }

    @Test func stretchesUpToOnePointOneFiveInFlight() {
        let frames = samples(flight(from: macBook, to: external))
        let stretch = frames.map(\.scaleX).max()!
        #expect(stretch > 1.12 && stretch <= ScreenFlight.maxStretch + 0.0001)
    }

    @Test func stretchesAlongItsHeading() {
        // A display above: it flies up, so it stretches up, not sideways.
        let above = ScreenGeometry(frame: CGRect(x: 0, y: 982, width: 2560, height: 1440), mode: .pill, notchRect: nil, menuBarHeight: 30)
        let frames = samples(flight(from: macBook, to: above))
        #expect(frames.map(\.scaleY).max()! > 1.1)
        #expect(frames.map(\.scaleX).max()! < 1.05)
    }

    @Test func docksWithoutASquash() {
        // Neither dock squashes: once it stops stretching, nothing scales it.
        for flight in [flight(from: external, to: macBook), flight(from: macBook, to: external)] {
            let resting = samples(flight).filter { $0.scaleX == 1 }
            #expect(!resting.isEmpty)
            #expect(resting.allSatisfy { $0.scaleY == 1 })
        }
    }

    @Test func contentGrowsInAsTheIslandArrives() {
        // Starts during the approach, well before touchdown …
        #expect(ScreenFlight.contentStart > ScreenFlight.flightStart + 0.15)
        #expect(ScreenFlight.contentStart < ScreenFlight.landingStart - 0.2)
        // … and is all there as the island lands.
        #expect(ScreenFlight.contentProgress(at: ScreenFlight.landingStart) > 0.97)
        #expect(ScreenFlight.contentProgress(at: ScreenFlight.handover) > 0.9999)
    }

    @Test func leavesInOneMotion() {
        // The source content dissolves while the island detaches, and the
        // flight's shadow comes in while the island fades out beneath it.
        #expect(ScreenFlight.sourceContentOpacity(at: 0) == 1)
        #expect(ScreenFlight.sourceContentOpacity(at: 0.14) == 0)
        #expect(ScreenFlight.departureFade(at: 0) == 0)
        #expect(ScreenFlight.departureFade(at: ScreenFlight.departure) == 1)
        // The shoulders retract over ≈ 60 ms or more, not in a snap.
        let flight = flight(from: macBook, to: external)
        #expect(flight.frame(at: 0.04).form.shoulderRadius > 1)
    }

    @Test func handsOverOnceItHasLanded() {
        // Content fully in before the cross-fade, which ends before the
        // flight windows go.
        #expect(ScreenFlight.contentProgress(at: ScreenFlight.handover) > 0.9999)
        #expect(ScreenFlight.handover + ScreenFlight.handoverFade < ScreenFlight.duration)
        // The flight's shadow goes linearly while the island's comes in.
        #expect(ScreenFlight.handoverShadow(at: ScreenFlight.handover) == 1)
        #expect(abs(ScreenFlight.handoverShadow(at: ScreenFlight.handover + ScreenFlight.handoverFade / 2) - 0.5) < 1e-6)
        #expect(ScreenFlight.handoverShadow(at: ScreenFlight.handover + ScreenFlight.handoverFade) < 1e-6)
        // The two images match: the shape has settled by the handover.
        let flight = flight(from: macBook, to: external)
        let atHandover = flight.frame(at: ScreenFlight.handover)
        #expect(abs(atHandover.form.rect.midX - flight.to.rect.midX) < 0.5)
        #expect(abs(atHandover.scaleY - 1) < 0.015)
    }

    @Test func onlyCompactAndMinimalFly() {
        #expect(ScreenFlight.flies(presentation: .compact, enabled: true, reduceMotion: false))
        #expect(ScreenFlight.flies(presentation: .minimal, enabled: true, reduceMotion: false))
        #expect(!ScreenFlight.flies(presentation: .idle, enabled: true, reduceMotion: false))
        #expect(!ScreenFlight.flies(presentation: .expanded, enabled: true, reduceMotion: false))
        #expect(!ScreenFlight.flies(presentation: .compact, enabled: false, reduceMotion: false))
        #expect(!ScreenFlight.flies(presentation: .compact, enabled: true, reduceMotion: true))
    }
}
