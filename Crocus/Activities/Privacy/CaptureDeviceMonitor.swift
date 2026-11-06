import CoreAudio
import CoreMediaIO
import Foundation
import os

/// Whether any app is using a camera or microphone right now.
struct CaptureUsage: Equatable, Sendable {
    var camera = false
    var microphone = false
}

/// Watches cameras and microphones; a fake in tests.
@MainActor
protocol CaptureMonitoring: AnyObject {
    var onChange: ((CaptureUsage) -> Void)? { get set }
    func start()
    func read() -> CaptureUsage
}

/// Which devices count: real hardware only. Virtual and aggregate devices
/// (Teams Audio, Loopback, OBS …) only pass audio/video on – when they
/// record, the real device runs too.
enum CaptureDeviceFilter {
    /// Transport types as four-character codes, e.g. 'bltn', 'usb ', 'virt'.
    static let ignored: Set<String> = ["virt", "grup"]

    static func counts(transport: UInt32) -> Bool {
        !ignored.contains(fourCC(transport))
    }

    static func fourCC(_ value: UInt32) -> String {
        String([24, 16, 8, 0].map { Character(UnicodeScalar(UInt8((value >> $0) & 0xFF))) })
    }
}

/// CoreAudio (`kAudioDevicePropertyDeviceIsRunningSomewhere`) for
/// microphones and CoreMediaIO (`kCMIODevicePropertyDeviceIsRunningSomewhere`)
/// for cameras. Only reads whether a device runs – records nothing, so no
/// permission dialog – and listens for changes instead of polling. Neither
/// API tells which app uses the device.
@MainActor
final class CaptureDeviceMonitor: CaptureMonitoring {
    var onChange: ((CaptureUsage) -> Void)?

    private var audioListened: Set<AudioObjectID> = []
    private var cameraListened: Set<CMIOObjectID> = []
    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Privacy")

    func start() {
        var devices = Self.audioAddress(kAudioHardwarePropertyDevices)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devices, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.devicesChanged() }
        }
        var cameras = Self.cmioAddress(kCMIOHardwarePropertyDevices)
        CMIOObjectAddPropertyListenerBlock(CMIOObjectID(kCMIOObjectSystemObject), &cameras, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.devicesChanged() }
        }
        listenToDevices()
        let microphones = Self.microphones().map { "\(Self.name($0)) [\(CaptureDeviceFilter.fourCC(Self.audioTransport($0)))]" }
        let cameraList = Self.cameras().map { "\($0) [\(CaptureDeviceFilter.fourCC(Self.cameraTransport($0)))]" }
        Self.logger.info("Microphones: \(microphones.joined(separator: ", "), privacy: .public); cameras: \(cameraList.joined(separator: ", "), privacy: .public)")
    }

    func read() -> CaptureUsage {
        CaptureUsage(
            camera: Self.cameras().contains { CaptureDeviceFilter.counts(transport: Self.cameraTransport($0)) && Self.cameraRunning($0) },
            microphone: Self.microphones().contains { CaptureDeviceFilter.counts(transport: Self.audioTransport($0)) && Self.audioRunning($0) }
        )
    }

    private func devicesChanged() {
        listenToDevices()
        onChange?(read())
    }

    /// Adds a "running somewhere" listener to devices not watched yet.
    private func listenToDevices() {
        for id in Self.microphones() where !audioListened.contains(id) {
            var address = Self.audioAddress(kAudioDevicePropertyDeviceIsRunningSomewhere)
            let status = AudioObjectAddPropertyListenerBlock(id, &address, .main) { [weak self] _, _ in
                MainActor.assumeIsolated { self.map { $0.onChange?($0.read()) } }
            }
            if status == noErr { audioListened.insert(id) }
        }
        for id in Self.cameras() where !cameraListened.contains(id) {
            var address = Self.cmioAddress(kCMIODevicePropertyDeviceIsRunningSomewhere, wildcard: true)
            let status = CMIOObjectAddPropertyListenerBlock(id, &address, .main) { [weak self] _, _ in
                MainActor.assumeIsolated { self.map { $0.onChange?($0.read()) } }
            }
            if status == 0 { cameraListened.insert(id) }
        }
    }

    // MARK: - CoreAudio

    private static func audioAddress(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    /// Devices with input streams.
    private static func microphones() -> [AudioObjectID] {
        var address = audioAddress(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.filter { id in
            var streams = audioAddress(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeInput)
            var streamSize: UInt32 = 0
            return AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr && streamSize > 0
        }
    }

    private static func audioUInt32(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32 {
        var address = audioAddress(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr ? value : 0
    }

    private static func audioRunning(_ id: AudioObjectID) -> Bool { audioUInt32(id, kAudioDevicePropertyDeviceIsRunningSomewhere) != 0 }
    private static func audioTransport(_ id: AudioObjectID) -> UInt32 { audioUInt32(id, kAudioDevicePropertyTransportType) }

    private static func name(_ id: AudioObjectID) -> String {
        var address = audioAddress(kAudioObjectPropertyName)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return "?" }
        return value?.takeRetainedValue() as String? ?? "?"
    }

    // MARK: - CoreMediaIO

    private static func cmioAddress(_ selector: Int, wildcard: Bool = false) -> CMIOObjectPropertyAddress {
        CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(selector),
            mScope: wildcard ? CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard) : CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: wildcard ? CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard) : CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
    }

    private static func cameras() -> [CMIOObjectID] {
        var address = cmioAddress(kCMIOHardwarePropertyDevices)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &size) == 0 else { return [] }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, size, &used, &ids) == 0 else { return [] }
        return ids
    }

    private static func cameraUInt32(_ id: CMIOObjectID, _ selector: Int) -> UInt32 {
        var address = cmioAddress(selector, wildcard: true)
        var value: UInt32 = 0
        var used: UInt32 = 0
        return CMIOObjectGetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &used, &value) == 0 ? value : 0
    }

    private static func cameraRunning(_ id: CMIOObjectID) -> Bool { cameraUInt32(id, kCMIODevicePropertyDeviceIsRunningSomewhere) != 0 }
    private static func cameraTransport(_ id: CMIOObjectID) -> UInt32 { cameraUInt32(id, kCMIODevicePropertyTransportType) }
}
