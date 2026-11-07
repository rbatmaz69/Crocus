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
        let lowest = samples(flight).map(\.form.rect.midY).min()!
        #expect(lowest < flight.to.rect.midY - 20)
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

    @Test func squashesToZeroPointNineOnLanding() {
        let landing = samples(flight(from: macBook, to: external)).filter { $0.scaleX < 1.001 }
        let squash = landing.map(\.scaleY).min()!
        #expect(abs(squash - ScreenFlight.landingSquash) < 0.01)
    }

    @Test func contentComesInWhileItTouchesDown() {
        #expect(ScreenFlight.contentOpacity(at: ScreenFlight.landingStart) == 0)
        #expect(ScreenFlight.contentOpacity(at: ScreenFlight.landingStart + 0.17) > 0.4)
        // Fully there well before the island takes over.
        #expect(ScreenFlight.contentOpacity(at: ScreenFlight.landingStart + 0.30) == 1)
        #expect(ScreenFlight.landingStart + 0.30 < ScreenFlight.duration)
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

    @Test func neverTwoShadowsAtTheHandover() {
        // The flight's shadow is fully there until the island shows beneath
        // it, and gone before the flight windows close.
        #expect(ScreenFlight.handoverFade(at: ScreenFlight.handover) == 1)
        #expect(ScreenFlight.handoverFade(at: ScreenFlight.duration - 0.02) == 0)
        #expect(ScreenFlight.handover > ScreenFlight.landingStart + 0.30)
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
