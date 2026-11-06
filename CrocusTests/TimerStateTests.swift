import Foundation
import Testing
@testable import Crocus

@Suite struct TimerStateTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func countsDown() {
        let state = TimerState.timer(duration: 600, now: t0)
        #expect(state.remaining(now: t0) == 600)
        #expect(state.remaining(now: t0 + 328) == 272)
        #expect(state.remainingFraction(now: t0 + 300) == 0.5)
        #expect(state.endDate == t0 + 600)
        #expect(state.remaining(now: t0 + 700) == 0)
    }

    @Test func durationIsClamped() {
        #expect(TimerState.timer(duration: 0, now: t0).duration == 1)
        #expect(TimerState.timer(duration: 100_000, now: t0).duration == 86_400)
    }

    @Test func pauseAndResume() {
        var state = TimerState.timer(duration: 600, now: t0)
        state.pause(now: t0 + 100)
        #expect(state.isPaused)
        #expect(state.remaining(now: t0 + 500) == 500)
        #expect(state.endDate == nil)
        #expect(state.nextDeadline(now: t0 + 500) == nil)

        state.resume(now: t0 + 500)
        #expect(state.isRunning)
        #expect(state.endDate == t0 + 1000)
        #expect(state.remaining(now: t0 + 600) == 400)
    }

    @Test func finishesAtTheEnd() {
        var state = TimerState.timer(duration: 60, now: t0)
        let early = state.finishIfDue(now: t0 + 59.9)
        #expect(!early)
        let due = state.finishIfDue(now: t0 + 61)
        #expect(due)
        #expect(state.phase == .finished(at: t0 + 60))
        #expect(state.remaining(now: t0 + 61) == 0)
        let again = state.finishIfDue(now: t0 + 62)
        #expect(!again) // only once
    }

    @Test func stopwatchCountsUpAndNeverFinishes() {
        var state = TimerState.stopwatch(now: t0)
        #expect(state.elapsed(now: t0 + 65) == 65)
        #expect(state.remaining(now: t0 + 65) == nil)
        #expect(state.endDate == nil)
        let finishes = state.finishIfDue(now: t0 + 100_000)
        #expect(!finishes)
        state.pause(now: t0 + 10)
        state.resume(now: t0 + 20)
        #expect(state.elapsed(now: t0 + 25) == 15)
    }

    @Test func finishedTimerIsRemovedAfterAMinuteOrOnceSeen() {
        var state = TimerState.timer(duration: 10, now: t0)
        state.finishIfDue(now: t0 + 10)
        #expect(!state.shouldRemove(now: t0 + 30, wasSeenExpanded: false, isExpanded: false))
        #expect(!state.shouldRemove(now: t0 + 30, wasSeenExpanded: true, isExpanded: true))
        #expect(state.shouldRemove(now: t0 + 30, wasSeenExpanded: true, isExpanded: false))
        #expect(state.shouldRemove(now: t0 + 70, wasSeenExpanded: false, isExpanded: true))
        #expect(state.nextDeadline(now: t0 + 30) == t0 + 31)
        #expect(state.nextDeadline(now: t0 + 69.5) == t0 + 70)
    }

    @Test func tickAnchorLandsOnWholeSeconds() throws {
        var timer = TimerState.timer(duration: 90.4, now: t0)
        let anchor = try #require(timer.tickAnchor)
        #expect(anchor <= t0)
        // Displayed (rounded-up) seconds change exactly at anchor + n.
        let end = try #require(timer.endDate)
        #expect(end.timeIntervalSince(anchor).truncatingRemainder(dividingBy: 1) == 0)

        var stopwatch = TimerState.stopwatch(now: t0)
        stopwatch.pause(now: t0 + 2.25)
        stopwatch.resume(now: t0 + 10)
        #expect(stopwatch.tickAnchor == t0 + 10 - 0.25)

        timer.pause(now: t0 + 1)
        #expect(timer.tickAnchor == nil)
    }

    @Test func restoreAfterRelaunch() {
        let running = TimerState.timer(duration: 600, now: t0)
        #expect(running.restored(now: t0 + 100) == running)

        // Ran out 30 s ago while Crocus was closed: comes back finished.
        let recent = running.restored(now: t0 + 630)
        #expect(recent?.phase == .finished(at: t0 + 600))

        // Ran out long ago: dropped.
        #expect(running.restored(now: t0 + 700) == nil)

        var paused = running
        paused.pause(now: t0 + 100)
        #expect(paused.restored(now: t0 + 100_000) == paused)
    }

    @Test func survivesEncoding() throws {
        var state = TimerState.timer(duration: 600, now: t0)
        state.pause(now: t0 + 42)
        let decoded = try JSONDecoder().decode(TimerState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
    }
}

@Suite struct TimerFormatTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func clock() {
        #expect(TimerFormat.clock(272, roundingUp: true) == "04:32")
        #expect(TimerFormat.clock(271.2, roundingUp: true) == "04:32")
        #expect(TimerFormat.clock(0.2, roundingUp: true) == "00:01")
        #expect(TimerFormat.clock(0, roundingUp: true) == "00:00")
        #expect(TimerFormat.clock(65.9, roundingUp: false) == "01:05")
        #expect(TimerFormat.clock(3872, roundingUp: false) == "1:04:32")
        #expect(TimerFormat.clock(-5, roundingUp: true) == "00:00")
    }

    @Test func subtitle() {
        let time: (Date) -> String = { "T+\(Int($0.timeIntervalSince(self.t0)))" }
        var timer = TimerState.timer(duration: 600, now: t0)
        #expect(TimerFormat.subtitle(timer, now: t0, timeStyle: time) == "Timer · 10:00 · ends T+600")
        timer.pause(now: t0 + 1)
        #expect(TimerFormat.subtitle(timer, now: t0, timeStyle: time) == "Timer · 10:00 · paused")
        timer.resume(now: t0 + 1)
        timer.finishIfDue(now: t0 + 601)
        #expect(TimerFormat.subtitle(timer, now: t0, timeStyle: time) == "Timer · 10:00 · ended T+600")
        #expect(TimerFormat.subtitle(.stopwatch(now: t0), now: t0, timeStyle: time) == "Stopwatch · since T+0")
    }

    @Test func accessibility() {
        var timer = TimerState.timer(duration: 600, now: t0)
        #expect(TimerFormat.accessibilityLabel(timer, now: t0 + 327.5) == "Timer, 4 minutes 33 seconds remaining")
        timer.pause(now: t0 + 540)
        #expect(TimerFormat.accessibilityLabel(timer, now: t0 + 540) == "Timer paused, 1 minute remaining")
        timer.resume(now: t0 + 540)
        timer.finishIfDue(now: t0 + 700)
        #expect(TimerFormat.accessibilityLabel(timer, now: t0 + 700) == "Timer finished")
        #expect(TimerFormat.accessibilityLabel(.stopwatch(now: t0), now: t0 + 3661) == "Stopwatch, 1 hour 1 minute 1 second")
    }
}
