import Foundation
import Testing
@testable import Crocus

@MainActor
@Suite struct LiveActivityManagerTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_000_000) }

    let clock = Clock()
    let store: IslandStore
    var opened: [URL] = []

    init() {
        let suite = "LiveActivityManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        store = IslandStore(defaults: defaults)
    }

    func manager() -> LiveActivityManager {
        let clock = clock
        return LiveActivityManager(store: store, now: { clock.now }, openURL: { _ in })
    }

    func start(_ manager: LiveActivityManager, id: String = "build", progress: LiveActivityProgress = .value(0.4)) {
        manager.handle(.start(id: id, fields: LiveActivityFields(title: "Build", symbol: "hammer", progress: progress)))
    }

    @Test func startPutsItIntoTheIsland() {
        let manager = manager()
        start(manager)
        #expect(store.presentation == .compact)
        #expect(store.primaryActivity?.kind == .liveActivity)
        #expect(manager.activities["build"]?.state.title == "Build")
    }

    @Test func updateChangesValuesInPlace() {
        let manager = manager()
        start(manager)
        clock.now += 5
        manager.handle(.update(id: "build", fields: LiveActivityFields(progress: .value(0.8), status: "256 of 320")))
        let state = manager.activities["build"]?.state
        #expect(state?.progress == .value(0.8))
        #expect(state?.status == "256 of 320")
    }

    @Test func endRemovesAfterThreeSeconds() {
        let manager = manager()
        start(manager)
        manager.handle(.end(id: "build", result: .success, text: nil))
        #expect(store.presentation == .compact)

        clock.now += 2.9
        manager.tick()
        #expect(manager.activities["build"] != nil)

        clock.now += 0.1
        manager.tick()
        #expect(manager.activities["build"] == nil)
        #expect(store.presentation == .idle)
    }

    @Test func unknownIDsAreIgnored() {
        let manager = manager()
        manager.handle(.update(id: "nope", fields: LiveActivityFields(progress: .value(1))))
        manager.handle(.end(id: "nope", result: .failure, text: nil))
        #expect(manager.activities.isEmpty)
        #expect(store.presentation == .idle)
    }

    @Test func hideRemovesImmediately() {
        let manager = manager()
        start(manager)
        manager.activities["build"]?.onHide?()
        #expect(manager.activities.isEmpty)
        #expect(store.presentation == .idle)
    }

    @Test func staleAfterEightHours() {
        let manager = manager()
        start(manager)
        clock.now += 8 * 3600
        manager.tick()
        #expect(manager.activities["build"]?.isStale == true)
        #expect(manager.activities["build"]?.accessibilityLabel.contains("No updates") == true)
    }

    @Test func restartWithSameID() {
        let manager = manager()
        start(manager)
        manager.handle(.end(id: "build", result: .failure, text: nil))
        start(manager, progress: .indeterminate)
        #expect(manager.activities["build"]?.state.isRunning == true)
        #expect(manager.activities["build"]?.state.progress == .indeterminate)
    }
}
