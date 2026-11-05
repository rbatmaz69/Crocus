import Testing
@testable import Crocus

@Suite struct PointerScreenDebouncerTests {
    let t0 = ContinuousClock.now

    func at(_ ms: Int) -> ContinuousClock.Instant { t0 + .milliseconds(ms) }

    @Test func firstScreenSettlesImmediately() {
        var debounce = PointerScreenDebounce()
        #expect(debounce.observe(1, at: at(0)) == 1)
        #expect(debounce.settled == 1)
    }

    @Test func switchesOnlyAfterOneSecond() {
        var debounce = PointerScreenDebounce(settled: 1)
        #expect(debounce.observe(2, at: at(0)) == nil)
        #expect(debounce.deadline == at(1000))
        #expect(debounce.observe(2, at: at(500)) == nil)
        #expect(debounce.observe(2, at: at(999)) == nil)
        #expect(debounce.observe(2, at: at(1000)) == 2)
        #expect(debounce.settled == 2)
        #expect(debounce.deadline == nil)
    }

    @Test func returningBeforeDeadlineCancels() {
        var debounce = PointerScreenDebounce(settled: 1)
        _ = debounce.observe(2, at: at(0))
        #expect(debounce.observe(1, at: at(600)) == nil)
        #expect(debounce.deadline == nil)
        #expect(debounce.observe(2, at: at(1200)) == nil) // timer starts over
        #expect(debounce.observe(2, at: at(2200)) == 2)
    }

    @Test func movingToAThirdScreenRestartsTimer() {
        var debounce = PointerScreenDebounce(settled: 1)
        _ = debounce.observe(2, at: at(0))
        _ = debounce.observe(3, at: at(800))
        #expect(debounce.observe(3, at: at(1500)) == nil)
        #expect(debounce.observe(3, at: at(1800)) == 3)
    }

    @Test func sameScreenNeverTriggers() {
        var debounce = PointerScreenDebounce(settled: 1)
        for ms in stride(from: 0, through: 5000, by: 250) {
            #expect(debounce.observe(1, at: at(ms)) == nil)
        }
    }

    @Test func gapsBetweenScreensKeepWaiting() {
        var debounce = PointerScreenDebounce(settled: 1)
        _ = debounce.observe(2, at: at(0))
        #expect(debounce.observe(nil, at: at(400)) == nil)
        #expect(debounce.observe(2, at: at(1000)) == 2)
    }

    @Test func forceSettlesWithoutDelay() {
        var debounce = PointerScreenDebounce(settled: 1)
        _ = debounce.observe(2, at: at(0))
        debounce.force(3)
        #expect(debounce.settled == 3)
        #expect(debounce.deadline == nil)
    }
}
