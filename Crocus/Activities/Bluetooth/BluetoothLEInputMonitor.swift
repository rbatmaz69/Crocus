import Foundation
import IOKit
import IOKit.hid
import os

/// Bluetooth Low Energy mice, keyboards and trackpads. IOBluetooth only
/// reports classic Bluetooth, and CoreBluetooth's connection events don't
/// exist on macOS – but BLE input devices appear in the I/O Registry as HID
/// devices with transport "Bluetooth Low Energy". Crocus is notified when
/// one appears or goes, reading only its registry properties (name, usage,
/// vendor) – it never opens the device or reads input.
@MainActor
final class BluetoothLEInputMonitor {
    /// A device connected (`true`) or went away (`false`).
    var onChange: ((BluetoothDeviceInfo, Bool) -> Void)?

    static let transport = "Bluetooth Low Energy"

    /// A device's interfaces appear one after another (a keyboard first as
    /// media keys, then as keyboard); wait this long, then report it once.
    static let settleTime: Duration = .milliseconds(500)

    private var port: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []
    /// Registry entry ID → the interface; one physical device shows up as
    /// several HID interfaces sharing vendor, product and name.
    private var entries: [UInt64: BluetoothDeviceInfo] = [:]
    /// Devices whose connect waits for their other interfaces.
    private var settling: [String: Task<Void, Never>] = [:]

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Bluetooth")

    /// Starts watching; returns the BLE input devices connected now.
    func start() -> [BluetoothDeviceInfo] {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return [] }
        self.port = port
        IONotificationPortSetDispatchQueue(port, .main)
        let context = Unmanaged.passUnretained(self).toOpaque()

        var added: io_iterator_t = 0
        let matching = Self.matching()
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, matching, { context, iterator in
            guard let context else { return }
            let monitor = Unmanaged<BluetoothLEInputMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { _ = monitor.drain(iterator, connected: true, notify: true) }
        }, context, &added)
        var removed: io_iterator_t = 0
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification, Self.matching(), { context, iterator in
            guard let context else { return }
            let monitor = Unmanaged<BluetoothLEInputMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { _ = monitor.drain(iterator, connected: false, notify: true) }
        }, context, &removed)
        iterators = [added, removed]

        // Draining arms the notifications; the first batch is what is
        // connected right now.
        let now = drain(added, connected: true, notify: false)
        drain(removed, connected: false, notify: false)
        Self.logger.info("BLE input devices connected: \(now.count, privacy: .public)")
        return now
    }

    /// Devices reported as connected, with the info used for them – also
    /// for their disconnect.
    private var reported: [String: BluetoothDeviceInfo] = [:]

    @discardableResult
    private func drain(_ iterator: io_iterator_t, connected: Bool, notify: Bool) -> [BluetoothDeviceInfo] {
        var changed: Set<String> = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var entryID: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(service, &entryID)
            if connected {
                guard let device = Self.info(service) else { continue }
                entries[entryID] = device
                changed.insert(device.address)
            } else if let device = entries.removeValue(forKey: entryID) {
                changed.insert(device.address)
            }
        }

        var devices: [BluetoothDeviceInfo] = []
        for address in changed {
            let interfaces = entries.values.filter { $0.address == address }
            if connected {
                guard reported[address] == nil, settling[address] == nil else { continue } // already known
                if notify {
                    settle(address)
                } else if let device = Self.merged(interfaces) {
                    reported[address] = device // there at launch: no event
                    devices.append(device)
                }
            } else if interfaces.isEmpty {
                if let pending = settling.removeValue(forKey: address) {
                    pending.cancel() // gone before it was reported
                } else if let device = reported.removeValue(forKey: address) {
                    devices.append(device)
                    if notify { onChange?(device, false) }
                }
            }
        }
        return devices
    }

    /// Reports a connected device once its interfaces have settled.
    private func settle(_ address: String) {
        settling[address] = Task { [weak self] in
            try? await Task.sleep(for: Self.settleTime)
            guard !Task.isCancelled, let self else { return }
            self.settling[address] = nil
            guard let device = Self.merged(self.entries.values.filter { $0.address == address }) else { return }
            self.reported[address] = device
            self.onChange?(device, true)
        }
    }

    /// One device from its interfaces: the most telling kind wins –
    /// mouse, keyboard, game controller, then anything.
    static func merged(_ interfaces: [BluetoothDeviceInfo]) -> BluetoothDeviceInfo? {
        guard let first = interfaces.first else { return nil }
        let order: [UInt32] = [
            BluetoothDeviceKind.PeripheralMinor.pointing, BluetoothDeviceKind.PeripheralMinor.keyboard,
            BluetoothDeviceKind.PeripheralMinor.gamepad, BluetoothDeviceKind.PeripheralMinor.joystick,
        ]
        let minor = order.first { minor in interfaces.contains { $0.classMinor == minor } } ?? 0
        return BluetoothDeviceInfo(address: first.address, name: first.name, classMajor: first.classMajor, classMinor: minor)
    }

    private static func matching() -> CFMutableDictionary {
        let dictionary = IOServiceMatching(kIOHIDDeviceKey) as NSMutableDictionary
        dictionary[kIOHIDTransportKey] = transport
        return dictionary
    }

    /// Name, kind (mouse/keyboard from the HID usage) and a stable id.
    private static func info(_ service: io_service_t) -> BluetoothDeviceInfo? {
        func property(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        let name = property(kIOHIDProductKey) as? String ?? "Bluetooth device"
        let usagePage = (property(kIOHIDPrimaryUsagePageKey) as? NSNumber)?.uint32Value
        let usage = (property(kIOHIDPrimaryUsageKey) as? NSNumber)?.uint32Value
        // Shared by all interfaces of one device (their unique IDs differ).
        let unique = "\(property(kIOHIDVendorIDKey) ?? 0)-\(property(kIOHIDProductIDKey) ?? 0)-\(name)"
        // Map to the Bluetooth device class the classic path uses.
        var minor: UInt32 = 0
        if usagePage == UInt32(kHIDPage_GenericDesktop) {
            switch usage.map(Int.init) {
            case kHIDUsage_GD_Mouse, kHIDUsage_GD_Pointer: minor = BluetoothDeviceKind.PeripheralMinor.pointing
            case kHIDUsage_GD_Keyboard, kHIDUsage_GD_Keypad: minor = BluetoothDeviceKind.PeripheralMinor.keyboard
            case kHIDUsage_GD_GamePad: minor = BluetoothDeviceKind.PeripheralMinor.gamepad
            case kHIDUsage_GD_Joystick: minor = BluetoothDeviceKind.PeripheralMinor.joystick
            default: break
            }
        }
        return BluetoothDeviceInfo(address: "ble:\(unique)", name: name, classMajor: BluetoothDeviceKind.Major.peripheral, classMinor: minor)
    }
}
