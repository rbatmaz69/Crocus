import AppKit
import SwiftUI
import os

/// The honest privacy indicator: shows when any app uses a camera or
/// microphone, always on top. It doesn't replace macOS's own indicator.
@MainActor
@Observable
final class PrivacyManager {
    static let activityID = "privacy"

    nonisolated static func settingsURL(for device: PrivacyState.Device) -> URL {
        let pane = device == .camera ? "Privacy_Camera" : "Privacy_Microphone"
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
    }

    private(set) var state = PrivacyState()
    private(set) var activity: PrivacyActivity?

    @ObservationIgnored private let store: IslandStore
    @ObservationIgnored private let monitor: any CaptureMonitoring
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let openURL: (URL) -> Void
    @ObservationIgnored private let announce: (String) -> Void
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Privacy")

    init(
        store: IslandStore,
        monitor: any CaptureMonitoring = CaptureDeviceMonitor(),
        now: @escaping () -> Date = Date.init,
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) },
        announce: @escaping (String) -> Void = { AccessibilityNotification.Announcement($0).post() }
    ) {
        self.store = store
        self.monitor = monitor
        self.now = now
        self.openURL = openURL
        self.announce = announce
    }

    func start() {
        monitor.onChange = { [weak self] usage in self?.update(usage) }
        monitor.start()
        update(monitor.read(), initial: true)
    }

    func update(_ usage: CaptureUsage, initial: Bool = false) {
        let before = Set(state.shown)
        let running = Set(PrivacyState.Device.allCases.filter { state.use($0)?.endedAt == nil && state.isShown($0) })
        state.apply(usage, now: now(), initial: initial)
        let nowRunning = Set(PrivacyState.Device.allCases.filter { state.use($0)?.endedAt == nil && state.isShown($0) })
        for device in PrivacyState.Device.allCases {
            if nowRunning.contains(device), !running.contains(device), !before.contains(device) {
                Self.logger.info("\(device.rawValue, privacy: .public) started")
                if !initial { announce(PrivacyFormat.announcement(device, started: true)) }
            } else if running.contains(device), !nowRunning.contains(device) {
                Self.logger.info("\(device.rawValue, privacy: .public) stopped")
            }
        }
        refresh()
    }

    /// Shows or hides the indicator and schedules the 2 s hide.
    func refresh() {
        let time = now()
        let before = Set(state.shown)
        state.prune(now: time)
        for device in before.subtracting(state.shown) {
            announce(PrivacyFormat.announcement(device, started: false))
        }

        if state.isEmpty {
            if activity != nil {
                activity = nil
                store.remove(id: Self.activityID)
                Self.logger.info("Indicator hidden")
            }
        } else if let activity {
            activity.update(state)
        } else {
            let activity = PrivacyActivity(state: state, startedAt: time)
            activity.onOpenSettings = { [weak self] in self?.openSettings() }
            self.activity = activity
            store.upsert(activity)
        }

        deadlineTask?.cancel()
        guard let deadline = state.nextDeadline() else { return }
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(deadline.timeIntervalSince(time), 0.05)), tolerance: .milliseconds(10))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    /// Privacy & Security → Camera (or Microphone if only that is in use).
    func openSettings() {
        openURL(Self.settingsURL(for: state.isShown(.camera) ? .camera : .microphone))
        store.collapse()
    }
}
