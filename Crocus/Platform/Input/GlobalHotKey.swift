import Carbon.HIToolbox
import os

/// A system-wide keyboard shortcut via Carbon `RegisterEventHotKey`. Works in
/// the App Sandbox and needs no Accessibility permission.
@MainActor
final class GlobalHotKey {
    var onPress: (() -> Void)?
    private(set) var registered: KeyboardShortcutSpec?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private static let signature: OSType = 0x4352_4353 // "CRCS"
    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Input")

    /// Registers the shortcut, replacing the previous one. `nil` removes it.
    func register(_ spec: KeyboardShortcutSpec?) {
        guard spec != registered else { return }
        unregister()
        guard let spec else { return }
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(spec.keyCode, spec.carbonModifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRef = ref
            registered = spec
            Self.logger.info("Global shortcut registered: \(spec.displayString, privacy: .public)")
        } else {
            Self.logger.error("Global shortcut \(spec.displayString, privacy: .public) unavailable (status \(status))")
        }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        registered = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { hotKey.onPress?() }
            return noErr
        }, 1, &eventType, context, &handlerRef)
    }
}
