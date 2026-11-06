import CoreBluetooth

enum BluetoothAccess: Equatable, Sendable {
    case notDetermined
    case granted
    /// Denied or restricted: Bluetooth events are off.
    case denied
}

/// The Bluetooth permission (Privacy & Security → Bluetooth); a fake in
/// tests.
@MainActor
protocol BluetoothAuthorizing: AnyObject {
    var status: BluetoothAccess { get }
    /// Shows the system dialog if not decided yet.
    func request() async -> BluetoothAccess
}

/// Reads the status without asking (`CBManager.authorization`); asks by
/// creating a central manager, the documented trigger for the dialog.
@MainActor
final class CoreBluetoothAuthorization: NSObject, BluetoothAuthorizing, CBCentralManagerDelegate {
    private var manager: CBCentralManager?
    private var waiting: CheckedContinuation<BluetoothAccess, Never>?

    var status: BluetoothAccess {
        switch CBManager.authorization {
        case .allowedAlways: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func request() async -> BluetoothAccess {
        guard status == .notDetermined else { return status }
        return await withCheckedContinuation { continuation in
            waiting = continuation
            manager = CBCentralManager(delegate: self, queue: .main)
        }
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            guard status != .notDetermined else { return } // still asking
            waiting?.resume(returning: status)
            waiting = nil
            manager = nil
        }
    }
}
