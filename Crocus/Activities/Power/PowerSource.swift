import Foundation
import IOKit.ps
import os

/// Reads the battery and reports every change IOKit announces – no polling.
@MainActor
final class PowerSource {
    var onChange: ((PowerSnapshot?) -> Void)?
    private var runLoopSource: CFRunLoopSource?

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Power")

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let source = Unmanaged<PowerSource>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { source.onChange?(PowerSource.read()) }
        }, context)?.takeRetainedValue() else {
            Self.logger.error("Power source notifications unavailable")
            return
        }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func stop() {
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode) }
        runLoopSource = nil
    }

    /// The internal battery now; `nil` without one.
    nonisolated static func read() -> PowerSnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        let descriptions = list.compactMap {
            IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any]
        }
        let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        return PowerSnapshot(descriptions: descriptions, providingType: providing)
    }
}
