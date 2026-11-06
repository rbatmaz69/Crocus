import IOBluetooth
import os

/// Reports Bluetooth devices connecting and disconnecting; a fake in tests.
@MainActor
protocol BluetoothMonitoring: AnyObject {
    var onChange: ((BluetoothDeviceInfo, _ connected: Bool) -> Void)? { get set }
    /// Starts listening; returns the devices connected right now.
    func start() -> [BluetoothDeviceInfo]
}

/// IOBluetooth connect notifications for any device, and a disconnect
/// notification per connected device – classic Bluetooth. Bluetooth Low
/// Energy mice and keyboards come from `BluetoothLEInputMonitor`. No
/// polling.
@MainActor
final class BluetoothMonitor: NSObject, BluetoothMonitoring {
    var onChange: ((BluetoothDeviceInfo, Bool) -> Void)?
    private let lowEnergyInput = BluetoothLEInputMonitor()
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Bluetooth")

    func start() -> [BluetoothDeviceInfo] {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        let connected = paired.filter { $0.isConnected() && $0.deviceClassMajor != 0 }
        for device in connected { watchDisconnect(device) }
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
        Self.logger.info("Paired: \(paired.count, privacy: .public), connected: \(connected.count, privacy: .public), listening: \(self.connectNotification != nil, privacy: .public)")
        lowEnergyInput.onChange = { [weak self] device, connected in self?.onChange?(device, connected) }
        // Classic entries for the same BLE device (paired list) are skipped:
        // IOBluetooth never reports BLE connects anyway.
        return connected.map(Self.info) + lowEnergyInput.start()
    }

    // IOBluetooth calls these on whatever thread delivered the event –
    // sometimes CoreBluetooth's background queue, not the main thread. So
    // they are nonisolated: read the device there, continue on main.

    @objc nonisolated private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let info = Self.info(device)
        // IOBluetooth also reports some Bluetooth Low Energy devices, without
        // a Class of Device (major 0). Those come from the HID path with
        // their real kind – skip them here so they aren't shown twice.
        guard info.classMajor != 0 else { return }
        nonisolated(unsafe) let device = device
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.watchDisconnect(device)
                self.onChange?(info, true)
            }
        }
    }

    @objc nonisolated private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let info = Self.info(device)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.disconnectNotifications.removeValue(forKey: info.address)?.unregister()
                self.onChange?(info, false)
            }
        }
    }

    private func watchDisconnect(_ device: IOBluetoothDevice) {
        let address = device.addressString ?? ""
        guard disconnectNotifications[address] == nil,
              let notification = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
        else { return }
        disconnectNotifications[address] = notification
    }

    nonisolated private static func info(_ device: IOBluetoothDevice) -> BluetoothDeviceInfo {
        BluetoothDeviceInfo(
            address: device.addressString ?? "",
            name: device.name ?? "Bluetooth device",
            classMajor: UInt32(device.deviceClassMajor),
            classMinor: UInt32(device.deviceClassMinor)
        )
    }
}
