import Foundation

/// Camera and microphone use over time, as a pure value. Shown at once when
/// a device starts; hidden 2 s after it stops, so a quick restart (switching
/// cameras in a call) doesn't flicker.
struct PrivacyState: Equatable, Sendable {
    enum Device: String, CaseIterable, Sendable {
        case camera
        case microphone
    }

    struct Use: Equatable, Sendable {
        /// When Crocus saw it start; `nil` if it already ran at launch.
        var since: Date?
        /// When it stopped; `nil` while running.
        var endedAt: Date?
    }

    static let hideDelay: TimeInterval = 2

    private(set) var uses: [Device: Use] = [:]

    func isShown(_ device: Device) -> Bool { uses[device] != nil }
    var isEmpty: Bool { uses.isEmpty }
    /// Shown devices, camera first.
    var shown: [Device] { Device.allCases.filter(isShown) }

    func use(_ device: Device) -> Use? { uses[device] }

    /// `initial`: the state Crocus finds at launch (start times unknown).
    mutating func apply(_ usage: CaptureUsage, now: Date, initial: Bool = false) {
        update(.camera, running: usage.camera, now: now, initial: initial)
        update(.microphone, running: usage.microphone, now: now, initial: initial)
        prune(now: now)
    }

    /// Drops devices stopped for 2 s.
    mutating func prune(now: Date) {
        uses = uses.filter { _, use in
            guard let ended = use.endedAt else { return true }
            return now.timeIntervalSince(ended) < Self.hideDelay
        }
    }

    func nextDeadline() -> Date? {
        uses.values.compactMap { $0.endedAt?.addingTimeInterval(Self.hideDelay) }.min()
    }

    private mutating func update(_ device: Device, running: Bool, now: Date, initial: Bool) {
        if running {
            if uses[device] == nil {
                uses[device] = Use(since: initial ? nil : now)
            } else {
                uses[device]?.endedAt = nil // restarted within 2 s: keep the start time
            }
        } else if uses[device]?.endedAt == nil, uses[device] != nil {
            uses[device]?.endedAt = now
        }
    }
}

/// Texts for the privacy indicator – never an app name: public APIs don't
/// tell which app uses a device.
enum PrivacyFormat {
    static func title(_ device: PrivacyState.Device) -> String {
        switch device {
        case .camera: "Camera active"
        case .microphone: "Microphone active"
        }
    }

    /// "For 12 min · used by an app", "Just now · …", "In use · …" when the
    /// start isn't known.
    static func subtitle(since: Date?, now: Date) -> String {
        "\(duration(since: since, now: now)) · used by an app"
    }

    static func duration(since: Date?, now: Date) -> String {
        guard let since else { return "In use" }
        let minutes = Int(max(now.timeIntervalSince(since), 0) / 60)
        switch minutes {
        case 0: return "Just now"
        case ..<60: return "For \(minutes) min"
        default: return "For \(minutes / 60) h \(minutes % 60) min"
        }
    }

    /// "Camera and microphone in use", "Camera in use", "Microphone in use".
    static func accessibilityLabel(_ devices: [PrivacyState.Device]) -> String {
        switch (devices.contains(.camera), devices.contains(.microphone)) {
        case (true, true): "Camera and microphone in use"
        case (true, false): "Camera in use"
        case (false, true): "Microphone in use"
        case (false, false): ""
        }
    }

    static func announcement(_ device: PrivacyState.Device, started: Bool) -> String {
        let name = device == .camera ? "Camera" : "Microphone"
        return started ? "\(name) in use" : "\(name) no longer in use"
    }
}
