import Foundation

/// A device as the monitor reports it: address, name, Bluetooth class.
struct BluetoothDeviceInfo: Equatable, Sendable {
    let address: String
    let name: String
    let classMajor: UInt32
    let classMinor: UInt32
}

/// What kind of device connected, for its symbol – from the Bluetooth
/// "Class of Device" (Assigned Numbers) and, for Apple and Beats, the name.
enum BluetoothDeviceKind: Equatable, Sendable, CaseIterable {
    case airPods, airPodsPro, airPodsMax, beats, headphones, speaker, car
    case keyboard, mouse, magicMouse, trackpad, gameController
    case phone, tablet, computer, watch, printer
    case other

    enum Major {
        static let computer: UInt32 = 0x01
        static let phone: UInt32 = 0x02
        static let audio: UInt32 = 0x04
        static let peripheral: UInt32 = 0x05
        static let imaging: UInt32 = 0x06
        static let wearable: UInt32 = 0x07
        static let toy: UInt32 = 0x08
    }

    enum AudioMinor {
        static let loudspeaker: UInt32 = 0x05
        static let portable: UInt32 = 0x07
        static let car: UInt32 = 0x08
        static let hiFi: UInt32 = 0x0A
    }

    enum PeripheralMinor {
        /// Upper two bits of the minor class.
        static let keyboard: UInt32 = 0x10
        static let pointing: UInt32 = 0x20
        /// Lower four bits.
        static let joystick: UInt32 = 0x01
        static let gamepad: UInt32 = 0x02
    }

    static let tabletMinor: UInt32 = 0x07

    init(_ device: BluetoothDeviceInfo) {
        let name = device.name.lowercased()
        let minor = device.classMinor
        switch device.classMajor {
        case Major.audio:
            if name.contains("airpods max") { self = .airPodsMax }
            else if name.contains("airpods pro") { self = .airPodsPro }
            else if name.contains("airpods") { self = .airPods }
            else if name.contains("beats") { self = .beats }
            else {
                switch minor {
                case AudioMinor.loudspeaker, AudioMinor.portable, AudioMinor.hiFi: self = .speaker
                case AudioMinor.car: self = .car
                default: self = .headphones // headset, hands-free, headphones, others
                }
            }
        case Major.peripheral:
            if name.contains("trackpad") { self = .trackpad }
            else if name.contains("magic mouse") { self = .magicMouse }
            else if minor & 0x0F == PeripheralMinor.joystick || minor & 0x0F == PeripheralMinor.gamepad { self = .gameController }
            else if minor & PeripheralMinor.pointing != 0 { self = .mouse } // also keyboard + mouse combos
            else if minor & PeripheralMinor.keyboard != 0 { self = .keyboard }
            else { self = .other }
        case Major.phone: self = .phone
        case Major.computer: self = minor == Self.tabletMinor || name.contains("ipad") ? .tablet : .computer
        case Major.wearable: self = .watch
        case Major.imaging: self = .printer
        case Major.toy: self = .gameController
        default:
            // Uncategorised: still recognise well-known names.
            if name.contains("airpods") { self = .airPods }
            else if name.contains("keyboard") { self = .keyboard }
            else if name.contains("mouse") { self = .mouse }
            else { self = .other }
        }
    }

    var symbol: String {
        switch self {
        case .airPods: "airpods"
        case .airPodsPro: "airpodspro"
        case .airPodsMax: "airpodsmax"
        case .beats: "beats.headphones"
        case .headphones: "headphones"
        case .speaker: "hifispeaker"
        case .car: "car"
        case .keyboard: "keyboard"
        case .mouse: "computermouse"
        case .magicMouse: "magicmouse"
        case .trackpad: "rectangle.and.hand.point.up.left"
        case .gameController: "gamecontroller"
        case .phone: "iphone"
        case .tablet: "ipad"
        case .computer: "laptopcomputer"
        case .watch: "applewatch"
        case .printer: "printer"
        case .other: "dot.radiowaves.left.and.right"
        }
    }
}

/// Decides which connects/disconnects are worth an event, as a pure value:
/// - devices already connected when Crocus starts: no event
/// - 5 s after the Mac wakes: none (devices reconnect on their own)
/// - a disconnect only for a device Crocus saw connected
struct BluetoothEventFilter: Sendable {
    static let wakeQuiet: TimeInterval = 5

    private(set) var connected: Set<String> = []
    private(set) var lastWake: Date?

    mutating func start(connected addresses: Set<String>) {
        connected = addresses
    }

    mutating func didWake(at date: Date) {
        lastWake = date
    }

    /// Whether to show the connect.
    mutating func connect(_ address: String, now: Date) -> Bool {
        guard connected.insert(address).inserted else { return false } // already known
        return !isQuiet(now: now)
    }

    /// Whether to show the disconnect.
    mutating func disconnect(_ address: String, now: Date) -> Bool {
        guard connected.remove(address) != nil else { return false }
        return !isQuiet(now: now)
    }

    private func isQuiet(now: Date) -> Bool {
        lastWake.map { now.timeIntervalSince($0) < Self.wakeQuiet } ?? false
    }
}
