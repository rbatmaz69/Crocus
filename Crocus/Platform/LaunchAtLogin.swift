import ServiceManagement
import os

/// "Launch at login" through `SMAppService` (works in the sandbox).
@MainActor
enum LaunchAtLogin {
    enum State: Equatable, Sendable {
        case enabled
        case disabled
        /// Registered, but the user still has to allow it in Login Items.
        case needsApproval
    }

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "LaunchAtLogin")

    nonisolated static func state(for status: SMAppService.Status) -> State {
        switch status {
        case .enabled: .enabled
        case .requiresApproval: .needsApproval
        default: .disabled
        }
    }

    static var state: State { state(for: SMAppService.mainApp.status) }

    @discardableResult
    static func set(_ enabled: Bool) -> State {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Launch at login \(enabled ? "on" : "off", privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
        let state = state
        logger.info("Launch at login: \(String(describing: state), privacy: .public)")
        return state
    }

    static func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
