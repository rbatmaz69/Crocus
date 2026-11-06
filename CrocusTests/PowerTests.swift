import Foundation
import Testing
@testable import Crocus

@Suite struct PowerSnapshotTests {
    /// Shaped like `IOPSGetPowerSourceDescription` on a MacBook.
    static func battery(current: Int = 80, max: Int = 100, state: String = "AC Power", charging: Bool = false) -> [String: Any] {
        [
            "Type": "InternalBattery", "Is Present": true, "Name": "InternalBattery-0",
            "Current Capacity": NSNumber(value: current), "Max Capacity": NSNumber(value: max),
            "Power Source State": state, "Is Charging": charging, "Is Charged": false,
        ]
    }

    @Test func readsTheInternalBattery() throws {
        let snapshot = try #require(PowerSnapshot(descriptions: [Self.battery()], providingType: "AC Power"))
        #expect(snapshot == PowerSnapshot(level: 80, isOnAC: true, isCharging: false))

        let onBattery = try #require(PowerSnapshot(descriptions: [Self.battery(current: 9, state: "Battery Power")], providingType: "Battery Power"))
        #expect(onBattery == PowerSnapshot(level: 9, isOnAC: false))
    }

    @Test func levelIsAPercentageOfMaxCapacity() throws {
        let snapshot = try #require(PowerSnapshot(descriptions: [Self.battery(current: 41, max: 50)], providingType: nil))
        #expect(snapshot.level == 82)
    }

    @Test func noBatteryNoSnapshot() {
        #expect(PowerSnapshot(descriptions: [], providingType: "AC Power") == nil)
        let ups: [String: Any] = ["Type": "UPS", "Current Capacity": 100, "Max Capacity": 100]
        #expect(PowerSnapshot(descriptions: [ups], providingType: "AC Power") == nil)
        var removed = Self.battery()
        removed["Is Present"] = false
        #expect(PowerSnapshot(descriptions: [removed], providingType: nil) == nil)
    }
}

@Suite struct PowerEventDetectorTests {
    func ac(_ level: Int) -> PowerSnapshot { PowerSnapshot(level: level, isOnAC: true, isCharging: true) }
    func battery(_ level: Int) -> PowerSnapshot { PowerSnapshot(level: level, isOnAC: false) }

    @Test func nothingAtLaunch() {
        var detector = PowerEventDetector()
        #expect(detector.process(ac(80)).isEmpty)
        var low = PowerEventDetector()
        #expect(low.process(battery(4)).isEmpty)
        #expect(low.process(battery(3)).isEmpty) // 10 % and 5 % were already reached at launch
    }

    @Test func plugInButNotUnplug() {
        var detector = PowerEventDetector()
        _ = detector.process(battery(60))
        #expect(detector.process(ac(60)) == [.pluggedIn(level: 60)])
        #expect(detector.process(ac(61)).isEmpty) // charging on
        #expect(detector.process(battery(61)).isEmpty) // unplugged
        #expect(detector.process(PowerSnapshot(level: 80, isOnAC: true, isCharging: false)) == [.pluggedIn(level: 80)]) // held at 80 %
    }

    @Test func lowBatteryOncePerThreshold() {
        var detector = PowerEventDetector()
        _ = detector.process(battery(12))
        #expect(detector.process(battery(11)).isEmpty)
        #expect(detector.process(battery(10)) == [.lowBattery(level: 10)])
        #expect(detector.process(battery(9)).isEmpty)
        #expect(detector.process(battery(6)).isEmpty)
        #expect(detector.process(battery(5)) == [.lowBattery(level: 5)])
        #expect(detector.process(battery(4)).isEmpty)
    }

    @Test func jumpingPastBothWarnsOnce() {
        var detector = PowerEventDetector()
        _ = detector.process(battery(20))
        #expect(detector.process(battery(4)) == [.lowBattery(level: 4)])
        #expect(detector.process(battery(3)).isEmpty)
    }

    @Test func wobblingAroundTenPercentDoesNotRepeat() {
        var detector = PowerEventDetector()
        _ = detector.process(battery(11))
        #expect(detector.process(battery(10)) == [.lowBattery(level: 10)])
        #expect(detector.process(battery(11)).isEmpty)
        #expect(detector.process(battery(10)).isEmpty)
        // Back 2 points above: armed again.
        #expect(detector.process(battery(12)).isEmpty)
        #expect(detector.process(battery(10)) == [.lowBattery(level: 10)])
    }

    @Test func plugInRearms() {
        var detector = PowerEventDetector()
        _ = detector.process(battery(11))
        _ = detector.process(battery(10))
        #expect(detector.process(ac(10)) == [.pluggedIn(level: 10)])
        // Unplugged again at 10 %: on battery and low – warn again.
        #expect(detector.process(battery(10)) == [.lowBattery(level: 10)])
    }

    @Test func noBatteryNoEvents() {
        var detector = PowerEventDetector()
        #expect(detector.process(nil).isEmpty)
        #expect(detector.process(nil).isEmpty)
    }
}

@MainActor
@Suite struct PowerManagerTests {
    final class Announcements { var texts: [String] = [] }

    let store: IslandStore
    let announcements = Announcements()

    init() {
        let suite = "PowerManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        store = IslandStore(defaults: defaults)
    }

    func manager() -> PowerManager {
        let announcements = announcements
        return PowerManager(store: store, source: nil, announce: { announcements.texts.append($0) })
    }

    @Test func plugInShowsTheChargingEvent() {
        let manager = manager()
        manager.process(PowerSnapshot(level: 60, isOnAC: false))
        manager.process(PowerSnapshot(level: 60, isOnAC: true, isCharging: true))
        #expect(store.currentEvent?.kind == .charging)
        #expect(store.currentEvent?.duration == .milliseconds(2500))
        #expect(store.currentEvent?.accessibilityLabel == "Charging, 60 percent")
        #expect(announcements.texts == ["Charging, 60 percent"])
    }

    @Test func lowBatteryShowsTheWarning() {
        let manager = manager()
        manager.process(PowerSnapshot(level: 11, isOnAC: false))
        manager.process(PowerSnapshot(level: 9, isOnAC: false))
        #expect(store.currentEvent?.kind == .lowBattery)
        #expect(store.currentEvent?.duration == .seconds(4))
        #expect(announcements.texts == ["Battery low, 9 percent"])
    }

    @Test func eventOverlaysTheRunningActivity() { // return afterwards: IslandStoreTests
        let manager = manager()
        let timer = TimerActivity(state: .timer(duration: 600, now: Date()))
        store.upsert(timer)
        manager.show(.pluggedIn(level: 82))
        #expect(store.display == .event("power.charging"))
        store.removeAll()
    }

    @Test func storyboardC6() {
        #expect(ChargingTimeline.boltBounce == .milliseconds(300))
        #expect(ChargingTimeline.fillStart == .milliseconds(300))
        #expect(ChargingTimeline.fillEnd == .milliseconds(900))
        #expect(EventKind.charging.defaultDuration == .milliseconds(2500))
        #expect(EventKind.lowBattery.defaultDuration == .seconds(4))
    }
}
