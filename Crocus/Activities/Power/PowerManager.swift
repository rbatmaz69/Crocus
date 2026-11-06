import SwiftUI
import os

/// Shows power events in the island: plugging in (2.5 s) and low battery
/// at 10 % and 5 % (4 s), then the island returns to what it showed.
@MainActor
final class PowerManager {
    private let store: IslandStore
    private let source: PowerSource?
    private let announce: (String) -> Void
    private var detector = PowerEventDetector()

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Power")

    init(
        store: IslandStore,
        source: PowerSource? = PowerSource(),
        announce: @escaping (String) -> Void = { AccessibilityNotification.Announcement($0).post() }
    ) {
        self.store = store
        self.source = source
        self.announce = announce
    }

    func start() {
        source?.onChange = { [weak self] snapshot in self?.process(snapshot) }
        source?.start()
        let snapshot = PowerSource.read()
        if let snapshot {
            Self.logger.info("Battery \(snapshot.level, privacy: .public) %, adapter: \(snapshot.isOnAC, privacy: .public), charging: \(snapshot.isCharging, privacy: .public)")
        } else {
            Self.logger.info("No internal battery: power events off")
        }
        process(snapshot)
    }

    func process(_ snapshot: PowerSnapshot?) {
        for event in detector.process(snapshot) {
            show(event)
        }
    }

    /// Shows an event as if it had happened (debug menu).
    func show(_ event: PowerEvent) {
        let islandEvent = Self.islandEvent(for: event)
        Self.logger.info("\(islandEvent.accessibilityLabel, privacy: .public)")
        store.post(islandEvent)
        announce(islandEvent.accessibilityLabel)
    }

    static func islandEvent(for event: PowerEvent) -> IslandEvent {
        switch event {
        case .pluggedIn(let level):
            IslandEvent(
                id: "power.charging",
                kind: .charging,
                accessibilityLabel: "Charging, \(level) percent",
                compactLeading: AnyView(ChargingBolt()),
                compactTrailing: AnyView(BatteryValue(level: level, color: CrocusColors.positive, fills: true))
            )
        case .lowBattery(let level):
            IslandEvent(
                id: "power.low",
                kind: .lowBattery,
                accessibilityLabel: "Battery low, \(level) percent",
                compactLeading: AnyView(LowBatteryWarning()),
                compactTrailing: AnyView(BatteryValue(level: level, color: CrocusColors.lowBattery, fills: false))
            )
        }
    }
}
