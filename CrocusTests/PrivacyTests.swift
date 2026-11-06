import Foundation
import Testing
@testable import Crocus

@Suite struct CaptureDeviceFilterTests {
    func code(_ string: String) -> UInt32 {
        string.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    @Test(arguments: ["bltn", "usb ", "blue", "bluh", "cont", "airp", "unkn"])
    func realDevicesCount(_ transport: String) {
        #expect(CaptureDeviceFilter.counts(transport: code(transport)))
    }

    @Test(arguments: ["virt", "grup"])
    func virtualAndAggregateDevicesDont(_ transport: String) {
        #expect(!CaptureDeviceFilter.counts(transport: code(transport)))
    }

    @Test func fourCC() {
        #expect(CaptureDeviceFilter.fourCC(code("bltn")) == "bltn")
    }
}

@Suite struct PrivacyStateTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func showsAtOnceAndHidesTwoSecondsAfter() {
        var state = PrivacyState()
        state.apply(CaptureUsage(camera: true), now: t0)
        #expect(state.shown == [.camera])
        #expect(state.use(.camera)?.since == t0)

        state.apply(CaptureUsage(), now: t0 + 60)
        #expect(state.shown == [.camera]) // still for 2 s
        #expect(state.nextDeadline() == t0 + 62)
        state.prune(now: t0 + 61.9)
        #expect(state.isShown(.camera))
        state.prune(now: t0 + 62)
        #expect(state.isEmpty)
    }

    @Test func quickRestartKeepsTheStartTime() {
        var state = PrivacyState()
        state.apply(CaptureUsage(camera: true), now: t0)
        state.apply(CaptureUsage(), now: t0 + 30)
        state.apply(CaptureUsage(camera: true), now: t0 + 31)
        #expect(state.use(.camera) == PrivacyState.Use(since: t0, endedAt: nil))
        #expect(state.nextDeadline() == nil)
    }

    @Test func bothDevicesCameraFirst() {
        var state = PrivacyState()
        state.apply(CaptureUsage(microphone: true), now: t0)
        state.apply(CaptureUsage(camera: true, microphone: true), now: t0 + 5)
        #expect(state.shown == [.camera, .microphone])
        #expect(state.use(.microphone)?.since == t0)
        #expect(state.use(.camera)?.since == t0 + 5)
    }

    @Test func alreadyRunningAtLaunchHasNoStartTime() {
        var state = PrivacyState()
        state.apply(CaptureUsage(microphone: true), now: t0, initial: true)
        #expect(state.use(.microphone)?.since == nil)
    }
}

@Suite struct PrivacyFormatTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func subtitleNeverNamesAnApp() {
        #expect(PrivacyFormat.subtitle(since: t0, now: t0 + 720) == "For 12 min · used by an app")
        #expect(PrivacyFormat.subtitle(since: t0, now: t0 + 30) == "Just now · used by an app")
        #expect(PrivacyFormat.subtitle(since: t0, now: t0 + 3900) == "For 1 h 5 min · used by an app")
        #expect(PrivacyFormat.subtitle(since: nil, now: t0) == "In use · used by an app")
    }

    @Test func accessibility() {
        #expect(PrivacyFormat.accessibilityLabel([.camera, .microphone]) == "Camera and microphone in use")
        #expect(PrivacyFormat.accessibilityLabel([.microphone]) == "Microphone in use")
        #expect(PrivacyFormat.announcement(.camera, started: true) == "Camera in use")
        #expect(PrivacyFormat.announcement(.microphone, started: false) == "Microphone no longer in use")
    }

    @Test func settingsURLs() {
        #expect(PrivacyManager.settingsURL(for: .camera).absoluteString.hasSuffix("Privacy_Camera"))
        #expect(PrivacyManager.settingsURL(for: .microphone).absoluteString.hasSuffix("Privacy_Microphone"))
    }
}

@MainActor
final class FakeCaptureMonitor: CaptureMonitoring {
    var onChange: ((CaptureUsage) -> Void)?
    var usage = CaptureUsage()
    func start() {}
    func read() -> CaptureUsage { usage }

    func set(_ usage: CaptureUsage) {
        self.usage = usage
        onChange?(usage)
    }
}

@MainActor
@Suite struct PrivacyManagerTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_000_000) }
    final class Log { var urls: [URL] = []; var spoken: [String] = [] }

    let clock = Clock()
    let log = Log()
    let monitor = FakeCaptureMonitor()
    let store: IslandStore

    init() {
        let suite = "PrivacyManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        store = IslandStore(defaults: defaults)
    }

    func manager() -> PrivacyManager {
        let clock = clock, log = log
        let manager = PrivacyManager(store: store, monitor: monitor, now: { clock.now },
                                     openURL: { log.urls.append($0) }, announce: { log.spoken.append($0) })
        manager.start()
        return manager
    }

    @Test func alwaysOnTop() {
        let manager = manager()
        store.upsert(TimerActivity(state: .timer(duration: 600, now: clock.now)))
        monitor.set(CaptureUsage(camera: true))
        #expect(store.primaryActivity?.kind == .cameraMicrophone)
        #expect(manager.activity != nil)
        store.removeAll()
    }

    @Test func startAndStopAreAnnouncedOnce() {
        let manager = manager()
        monitor.set(CaptureUsage(microphone: true))
        monitor.set(CaptureUsage(microphone: true)) // repeated notification
        #expect(log.spoken == ["Microphone in use"])

        monitor.set(CaptureUsage())
        #expect(manager.activity != nil) // 2 s grace
        clock.now += 2
        manager.refresh()
        #expect(manager.activity == nil)
        #expect(store.presentation == .idle)
        #expect(log.spoken == ["Microphone in use", "Microphone no longer in use"])
    }

    @Test func notAnnouncedAtLaunch() {
        monitor.usage = CaptureUsage(camera: true)
        let manager = manager()
        #expect(manager.activity != nil)
        #expect(log.spoken.isEmpty)
    }

    @Test func settingsLink() {
        let manager = manager()
        monitor.set(CaptureUsage(microphone: true))
        manager.openSettings()
        monitor.set(CaptureUsage(camera: true, microphone: true))
        manager.openSettings()
        #expect(log.urls.map { $0.absoluteString.components(separatedBy: "?").last } == ["Privacy_Microphone", "Privacy_Camera"])
    }
}
