import AppKit
import Foundation
import Testing
@testable import Crocus

@Suite struct BluetoothDeviceKindTests {
    func device(_ name: String, major: UInt32 = 0x04, minor: UInt32 = 0x06) -> BluetoothDeviceInfo {
        BluetoothDeviceInfo(address: "aa-bb", name: name, classMajor: major, classMinor: minor)
    }

    @Test func appleAndBeats() {
        #expect(BluetoothDeviceKind(device("AirPods von Bilal")).symbol == "airpods")
        #expect(BluetoothDeviceKind(device("Bilal's AirPods Pro")).symbol == "airpodspro")
        #expect(BluetoothDeviceKind(device("AirPods Max")).symbol == "airpodsmax")
        #expect(BluetoothDeviceKind(device("Powerbeats Pro")).symbol == "beats.headphones")
    }

    @Test func byAudioClass() {
        #expect(BluetoothDeviceKind(device("Nothing Headphone (1)", minor: 0x01)).symbol == "headphones") // headset
        #expect(BluetoothDeviceKind(device("UGREEN HiTune Max5c", minor: 0x01)).symbol == "headphones")
        #expect(BluetoothDeviceKind(device("JBL Flip", minor: 0x05)).symbol == "hifispeaker")
        #expect(BluetoothDeviceKind(device("Car Kit", minor: 0x08)).symbol == "car")
    }

    @Test func peripherals() {
        #expect(BluetoothDeviceKind(device("MX Master 3S", major: 0x05, minor: 0x20)).symbol == "computermouse")
        #expect(BluetoothDeviceKind(device("Yoga Mouse with Laser", major: 0x05, minor: 0x20)).symbol == "computermouse")
        #expect(BluetoothDeviceKind(device("Flow2-84@Lofree", major: 0x05, minor: 0x10)).symbol == "keyboard")
        #expect(BluetoothDeviceKind(device("Function Trackpad", major: 0x05, minor: 0x20)).symbol == "rectangle.and.hand.point.up.left")
        #expect(BluetoothDeviceKind(device("Magic Mouse", major: 0x05, minor: 0x20)).symbol == "magicmouse")
        #expect(BluetoothDeviceKind(device("Xbox Wireless Controller", major: 0x05, minor: 0x02)).symbol == "gamecontroller")
        #expect(BluetoothDeviceKind(device("Combo", major: 0x05, minor: 0x30)).symbol == "computermouse")
    }

    @Test func otherClasses() {
        #expect(BluetoothDeviceKind(device("iPhone", major: 0x02, minor: 0x03)).symbol == "iphone")
        #expect(BluetoothDeviceKind(device("iPad", major: 0x01, minor: 0x07)).symbol == "ipad")
        #expect(BluetoothDeviceKind(device("MacBook", major: 0x01, minor: 0x03)).symbol == "laptopcomputer")
        #expect(BluetoothDeviceKind(device("Watch", major: 0x07, minor: 0x01)).symbol == "applewatch")
        #expect(BluetoothDeviceKind(device("Printer", major: 0x06, minor: 0x20)).symbol == "printer")
    }

    @Test func uncategorisedByName() {
        #expect(BluetoothDeviceKind(device("AirPods", major: 0x1F)).symbol == "airpods")
        #expect(BluetoothDeviceKind(device("Some Keyboard", major: 0x1F)).symbol == "keyboard")
        #expect(BluetoothDeviceKind(device("Tag", major: 0x1F)).symbol == "dot.radiowaves.left.and.right")
    }

    @Test(arguments: BluetoothDeviceKind.allCases)
    func everySymbolExists(_ kind: BluetoothDeviceKind) {
        #expect(NSImage(systemSymbolName: kind.symbol, accessibilityDescription: nil) != nil)
    }
}

@Suite struct BluetoothEventFilterTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func alreadyConnectedAtLaunchIsSilent() {
        var filter = BluetoothEventFilter()
        filter.start(connected: ["mouse"])
        let r1 = filter.connect("mouse", now: t0)
        #expect(!r1) // IOBluetooth repeats it
        let r2 = filter.connect("airpods", now: t0)
        #expect(r2)
        let r3 = filter.connect("airpods", now: t0 + 1)
        #expect(!r3) // repeated
    }

    @Test func disconnectOnlyForKnownDevices() {
        var filter = BluetoothEventFilter()
        filter.start(connected: [])
        let r4 = filter.disconnect("unknown", now: t0)
        #expect(!r4)
        _ = filter.connect("airpods", now: t0)
        let r5 = filter.disconnect("airpods", now: t0 + 5)
        #expect(r5)
        let r6 = filter.disconnect("airpods", now: t0 + 6)
        #expect(!r6)
    }

    @Test func quietForFiveSecondsAfterWake() {
        var filter = BluetoothEventFilter()
        filter.start(connected: [])
        filter.didWake(at: t0)
        let r7 = filter.connect("mouse", now: t0 + 2)
        #expect(!r7)
        let r8 = filter.connect("airpods", now: t0 + 5)
        #expect(r8)
        // A device that reconnected during the quiet time is still known.
        let r9 = filter.disconnect("mouse", now: t0 + 60)
        #expect(r9)
    }
}

@MainActor
final class FakeBluetoothMonitor: BluetoothMonitoring {
    var onChange: ((BluetoothDeviceInfo, Bool) -> Void)?
    var connectedNow: [BluetoothDeviceInfo] = []
    var started = 0

    func start() -> [BluetoothDeviceInfo] {
        started += 1
        return connectedNow
    }
}

@MainActor
final class FakeBluetoothAuthorization: BluetoothAuthorizing {
    var status: BluetoothAccess = .granted
    var answer: BluetoothAccess = .granted
    func request() async -> BluetoothAccess {
        status = answer
        return status
    }
}

@MainActor
@Suite struct BluetoothManagerTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_000_000) }
    final class Spoken { var texts: [String] = [] }
    /// The monitor holds the manager weakly – keep it alive for the test.
    final class Keep { var manager: BluetoothManager? }

    let clock = Clock()
    let spoken = Spoken()
    let keep = Keep()
    let monitor = FakeBluetoothMonitor()
    let authorization = FakeBluetoothAuthorization()
    let store: IslandStore

    let airPods = BluetoothDeviceInfo(address: "airpods", name: "AirPods von Bilal", classMajor: 0x04, classMinor: 0x06)
    let mouse = BluetoothDeviceInfo(address: "mouse", name: "MX Master 3S", classMajor: 0x05, classMinor: 0x20)

    init() {
        let suite = "BluetoothManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        store = IslandStore(defaults: defaults)
    }

    func manager() -> BluetoothManager {
        let clock = clock, spoken = spoken
        let manager = BluetoothManager(store: store, monitor: monitor, authorization: authorization,
                                       now: { clock.now }, announce: { spoken.texts.append($0) })
        manager.start()
        keep.manager = manager
        return manager
    }

    @Test func connectShowsATwoSecondEvent() {
        _ = manager()
        monitor.onChange?(airPods, true)
        #expect(store.currentEvent?.kind == .bluetooth)
        #expect(store.currentEvent?.duration == .seconds(2))
        #expect(store.currentEvent?.accessibilityLabel == "AirPods von Bilal connected")
        #expect(spoken.texts == ["AirPods von Bilal connected"])
    }

    @Test func disconnectToo() {
        _ = manager()
        monitor.onChange?(airPods, true)
        clock.now += 10
        monitor.onChange?(airPods, false)
        #expect(spoken.texts.last == "AirPods von Bilal disconnected")
    }

    @Test func miceToo() {
        _ = manager()
        monitor.onChange?(mouse, true)
        #expect(store.currentEvent?.kind == .bluetooth)
        #expect(spoken.texts == ["MX Master 3S connected"])
    }

    @Test func devicesConnectedAtLaunchAreSilent() {
        monitor.connectedNow = [airPods]
        _ = manager()
        monitor.onChange?(airPods, true)
        #expect(store.currentEvent == nil)
    }

    @Test func neverAsksOnItsOwn() async {
        authorization.status = .notDetermined
        let manager = manager()
        #expect(monitor.started == 0)
        #expect(manager.access == .notDetermined)

        await manager.requestAccess()
        #expect(manager.access == .granted)
        #expect(monitor.started == 1)
    }

    @Test func deniedMeansOff() async {
        authorization.status = .notDetermined
        authorization.answer = .denied
        let manager = manager()
        await manager.requestAccess()
        #expect(manager.access == .denied)
        #expect(monitor.started == 0)
    }
}

@Suite struct BluetoothLEInterfaceTests {
    func interface(_ minor: UInt32) -> BluetoothDeviceInfo {
        BluetoothDeviceInfo(address: "ble:1133-45066-Flow2-84@Lofree", name: "Flow2-84@Lofree", classMajor: 0x05, classMinor: minor)
    }

    @MainActor @Test func keyboardWithMediaKeysIsOneKeyboard() {
        // Media keys (no Generic Desktop usage) arrive first, then the keyboard.
        let merged = BluetoothLEInputMonitor.merged([interface(0), interface(0x10)])
        #expect(merged.map { BluetoothDeviceKind($0).symbol } == "keyboard")
    }

    @MainActor @Test func mouseWinsOverItsKeyboardInterface() {
        // Mice with extra buttons also expose a keyboard interface.
        let merged = BluetoothLEInputMonitor.merged([interface(0x10), interface(0x20)])
        #expect(merged.map { BluetoothDeviceKind($0).symbol } == "computermouse")
    }

    @MainActor @Test func nothingToMerge() {
        #expect(BluetoothLEInputMonitor.merged([]) == nil)
    }
}
