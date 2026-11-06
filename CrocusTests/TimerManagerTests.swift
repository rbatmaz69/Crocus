import Foundation
import Testing
@testable import Crocus

@MainActor
@Suite struct TimerManagerTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_000_000) }
    final class Finished { var states: [TimerState] = [] }

    let clock = Clock()
    let finished = Finished()
    let defaults: UserDefaults
    let store: IslandStore

    init() {
        let suite = "TimerManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        store = IslandStore(defaults: defaults)
    }

    func manager(store: IslandStore? = nil) -> TimerManager {
        let clock = clock, finished = finished
        return TimerManager(
            store: store ?? self.store, defaults: defaults, now: { clock.now },
            effects: .init { finished.states.append($0) }
        )
    }

    @Test func startShowsTheTimer() {
        let manager = manager()
        manager.startTimer(duration: 600)
        #expect(store.presentation == .compact)
        #expect(store.primaryActivity?.kind == .timer)
        #expect(store.primaryActivity?.id == "timer.timer")
    }

    @Test func timerAndStopwatchAtTheSameTime() {
        let manager = manager()
        manager.startTimer(duration: 600)
        manager.startStopwatch()
        #expect(store.activities.count == 2)
        #expect(store.presentation == .minimal)
    }

    @Test func newTimerReplacesTheRunningOne() {
        let manager = manager()
        manager.startTimer(duration: 600)
        clock.now += 10
        manager.startTimer(duration: 60)
        #expect(store.activities.count == 1)
        #expect(manager.state(.timer)?.duration == 60)
        #expect(manager.state(.timer)?.startedAt == clock.now)
    }

    @Test func finishAnnouncesOnceAndBounces() {
        let manager = manager()
        manager.startTimer(duration: 60)
        clock.now += 59
        manager.tick()
        #expect(finished.states.isEmpty)

        clock.now += 1
        manager.tick()
        manager.tick()
        #expect(finished.states.count == 1)
        #expect(manager.timers[.timer]?.finishCount == 1)
        #expect(manager.state(.timer)?.isFinished == true)
        #expect(store.presentation == .compact) // still shown
    }

    @Test func finishedTimerGoesAfterAMinute() {
        let manager = manager()
        manager.startTimer(duration: 10)
        clock.now += 10
        manager.tick()
        clock.now += 59
        manager.tick()
        #expect(manager.state(.timer) != nil)
        clock.now += 1
        manager.tick()
        #expect(manager.state(.timer) == nil)
        #expect(store.presentation == .idle)
    }

    @Test func finishedTimerGoesOnceSeenExpanded() {
        let manager = manager()
        manager.startTimer(duration: 10)
        clock.now += 10
        manager.tick()
        store.expand(id: "timer.timer")
        manager.tick()
        #expect(manager.state(.timer) != nil)
        store.collapse()
        manager.tick()
        #expect(manager.state(.timer) == nil)
    }

    @Test func pauseResumeStop() {
        let manager = manager()
        manager.startTimer(duration: 600)
        clock.now += 100
        manager.pause(.timer)
        clock.now += 1000
        manager.tick()
        #expect(finished.states.isEmpty)
        #expect(manager.state(.timer)?.remaining(now: clock.now) == 500)

        manager.resume(.timer)
        #expect(manager.state(.timer)?.endDate == clock.now + 500)

        manager.stop(.timer)
        #expect(manager.state(.timer) == nil)
        #expect(store.presentation == .idle)
    }

    @Test func restartAndAddMinute() {
        let manager = manager()
        manager.startTimer(duration: 300)
        clock.now += 300
        manager.tick()
        manager.restart(.timer)
        #expect(manager.state(.timer)?.isRunning == true)
        #expect(manager.state(.timer)?.duration == 300)

        clock.now += 300
        manager.tick()
        manager.addMinute()
        #expect(manager.state(.timer)?.duration == 60)
        #expect(manager.state(.timer)?.isRunning == true)
    }

    @Test func survivesRelaunch() {
        let first = manager()
        first.startTimer(duration: 600)
        first.startStopwatch()
        clock.now += 100
        first.pause(.stopwatch)

        clock.now += 50
        let otherStore = IslandStore(defaults: defaults)
        let second = manager(store: otherStore)
        second.start()
        #expect(second.state(.timer)?.remaining(now: clock.now) == 450)
        #expect(second.state(.stopwatch)?.elapsed(now: clock.now) == 100)
        #expect(second.state(.stopwatch)?.isPaused == true)
        #expect(otherStore.activities.count == 2)
    }

    @Test func timerThatRanOutWhileClosed() {
        manager().startTimer(duration: 60)

        // Closed for 90 s: ended 30 s ago → shown finished and announced.
        clock.now += 90
        let recent = manager(store: IslandStore(defaults: defaults))
        recent.start()
        #expect(recent.state(.timer)?.isFinished == true)
        #expect(finished.states.count == 1)

        // Closed much longer: dropped silently.
        manager().startTimer(duration: 60)
        clock.now += 3600
        let late = manager(store: IslandStore(defaults: defaults))
        late.start()
        #expect(late.state(.timer) == nil)
        #expect(finished.states.count == 1)
    }

    @Test func finishedTimerIsNotAnnouncedAgainAfterRelaunch() {
        let first = manager()
        first.startTimer(duration: 60)
        clock.now += 60
        first.tick()
        #expect(finished.states.count == 1)

        clock.now += 20
        let second = manager(store: IslandStore(defaults: defaults))
        second.start()
        #expect(second.state(.timer)?.isFinished == true)
        #expect(finished.states.count == 1)
    }

    @Test func stoppedTimersAreNotRestored() {
        let first = manager()
        first.startTimer(duration: 600)
        first.stop(.timer)
        let second = manager(store: IslandStore(defaults: defaults))
        second.start()
        #expect(second.timers.isEmpty)
    }

    // MARK: Intents

    @Test func intentsStartAndControl() throws {
        let manager = manager()
        let handler = TimerIntentHandler(manager: manager)
        try handler.startTimer(seconds: 90)
        #expect(manager.state(.timer)?.duration == 90)
        try handler.control(.pause, .timer)
        #expect(manager.state(.timer)?.isPaused == true)
        try handler.control(.resume, .timer)
        #expect(manager.state(.timer)?.isRunning == true)
        try handler.control(.stop, .timer)
        #expect(manager.state(.timer) == nil)

        handler.startStopwatch()
        #expect(manager.state(.stopwatch)?.isRunning == true)
    }

    @Test func intentErrors() {
        let handler = TimerIntentHandler(manager: manager())
        #expect(throws: TimerIntentError.invalidDuration) { try handler.startTimer(seconds: 0) }
        #expect(throws: TimerIntentError.invalidDuration) { try handler.startTimer(seconds: 90_000) }
        #expect(throws: TimerIntentError.invalidDuration) { try handler.startTimer(seconds: .nan) }
        #expect(throws: TimerIntentError.notRunning(.stopwatch)) { try handler.control(.pause, .stopwatch) }
        #expect(String(localized: TimerIntentError.notRunning(.timer).localizedStringResource) == "No timer is running.")
    }
}
