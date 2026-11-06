import Foundation

/// The internal battery at one moment, from IOKit's power source info.
struct PowerSnapshot: Equatable, Sendable {
    /// 0–100.
    var level: Int
    /// Power adapter attached (charging or not – e.g. held at 80 %).
    var isOnAC: Bool
    var isCharging: Bool

    /// From `IOPSGetPowerSourceDescription` dictionaries; `nil` without an
    /// internal battery (desktop Macs – then there are no power events).
    init?(descriptions: [[String: Any]], providingType: String?) {
        guard let battery = descriptions.first(where: {
            ($0["Type"] as? String) == "InternalBattery" && ($0["Is Present"] as? Bool ?? true)
        }),
            let current = (battery["Current Capacity"] as? NSNumber)?.doubleValue,
            let maximum = (battery["Max Capacity"] as? NSNumber)?.doubleValue, maximum > 0
        else { return nil }
        level = Int((current / maximum * 100).rounded()).clamped(to: 0...100)
        let state = battery["Power Source State"] as? String ?? providingType
        isOnAC = state == "AC Power"
        isCharging = battery["Is Charging"] as? Bool ?? false
    }

    init(level: Int, isOnAC: Bool, isCharging: Bool = false) {
        self.level = level
        self.isOnAC = isOnAC
        self.isCharging = isCharging
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
