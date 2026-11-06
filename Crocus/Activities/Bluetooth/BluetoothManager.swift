import AppKit
import SwiftUI
import os

/// Short events (2 s) when a Bluetooth device connects or disconnects;
/// then the island returns to what it showed.
@MainActor
@Observable
final class BluetoothManager {
    /// Privacy & Security → Bluetooth, to allow it later.
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!

    private(set) var access: BluetoothAccess = .notDetermined

    @ObservationIgnored private let store: IslandStore
    @ObservationIgnored private let monitor: any BluetoothMonitoring
    @ObservationIgnored private let authorization: any BluetoothAuthorizing
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let announce: (String) -> Void
    @ObservationIgnored private var filter = BluetoothEventFilter()
    @ObservationIgnored private var listening = false
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Bluetooth")

    init(
        store: IslandStore,
        monitor: any BluetoothMonitoring = BluetoothMonitor(),
        authorization: any BluetoothAuthorizing = CoreBluetoothAuthorization(),
        now: @escaping () -> Date = Date.init,
        announce: @escaping (String) -> Void = { AccessibilityNotification.Announcement($0).post() }
    ) {
        self.store = store
        self.monitor = monitor
        self.authorization = authorization
        self.now = now
        self.announce = announce
    }

    /// Starts listening if Bluetooth is allowed – never asks on its own.
    func start() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.didWake() }
        }
        access = authorization.status
        listenIfAllowed()
    }

    /// Menu bar: "Allow Bluetooth…".
    func requestAccess() async {
        access = await authorization.request()
        Self.logger.info("Bluetooth access: \(String(describing: self.access), privacy: .public)")
        listenIfAllowed()
    }

    func didWake() {
        filter.didWake(at: now())
    }

    private func listenIfAllowed() {
        guard access == .granted, !listening else { return }
        listening = true
        monitor.onChange = { [weak self] device, connected in self?.handle(device, connected: connected) }
        filter.start(connected: Set(monitor.start().map(\.address)))
    }

    func handle(_ device: BluetoothDeviceInfo, connected: Bool) {
        let time = now()
        let worthShowing = connected ? filter.connect(device.address, now: time) : filter.disconnect(device.address, now: time)
        guard worthShowing else { return }
        show(BluetoothDeviceKind(device), name: device.name, connected: connected)
    }

    /// Posts the event (also from the debug menu).
    func show(_ kind: BluetoothDeviceKind, name: String, connected: Bool) {
        let label = "\(name) \(connected ? "connected" : "disconnected")"
        Self.logger.info("\(kind.symbol, privacy: .public) \(connected ? "connected" : "disconnected", privacy: .public)")
        store.post(IslandEvent(
            id: "bluetooth",
            kind: .bluetooth,
            accessibilityLabel: label,
            compactLeading: AnyView(IslandCompactSymbol(systemName: kind.symbol)),
            compactTrailing: AnyView(IslandCompactValue(
                text: connected ? "Connected" : "Disconnected",
                color: connected ? CrocusColors.positive : CrocusColors.secondary
            ))
        ))
        announce(label)
    }
}
