import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut: virtual key code plus modifiers. Stored as a
/// string like "ctrl+opt+49"; recorded in Settings › General.
struct KeyboardShortcutSpec: Equatable, Sendable {
    struct Modifiers: OptionSet, Sendable {
        let rawValue: Int
        static let control = Modifiers(rawValue: 1 << 0)
        static let option = Modifiers(rawValue: 1 << 1)
        static let shift = Modifiers(rawValue: 1 << 2)
        static let command = Modifiers(rawValue: 1 << 3)
    }

    let keyCode: UInt32
    let modifiers: Modifiers

    /// ⌃⌥Space.
    static let `default` = KeyboardShortcutSpec(keyCode: UInt32(kVK_Space), modifiers: [.control, .option])

    private static let names: [(Modifiers, String, String)] = [
        (.control, "ctrl", "⌃"), (.option, "opt", "⌥"), (.shift, "shift", "⇧"), (.command, "cmd", "⌘"),
    ]

    init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// A key pressed in the recorder; needs at least one of ⌃⌥⇧⌘.
    init?(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        var modifiers: Modifiers = []
        if modifierFlags.contains(.control) { modifiers.insert(.control) }
        if modifierFlags.contains(.option) { modifiers.insert(.option) }
        if modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if modifierFlags.contains(.command) { modifiers.insert(.command) }
        guard !modifiers.isEmpty else { return nil }
        self.init(keyCode: UInt32(keyCode), modifiers: modifiers)
    }

    /// Parses "ctrl+opt+49"; needs at least one modifier.
    init?(string: String) {
        var parts = string.lowercased().split(separator: "+").map(String.init)
        guard let last = parts.popLast(), let code = UInt32(last) else { return nil }
        var modifiers: Modifiers = []
        for part in parts {
            guard let entry = Self.names.first(where: { $0.1 == part }) else { return nil }
            modifiers.insert(entry.0)
        }
        guard !modifiers.isEmpty else { return nil }
        self.init(keyCode: code, modifiers: modifiers)
    }

    var stringValue: String {
        (Self.names.filter { modifiers.contains($0.0) }.map(\.1) + [String(keyCode)]).joined(separator: "+")
    }

    /// e.g. "⌃⌥Space".
    var displayString: String {
        Self.names.filter { modifiers.contains($0.0) }.map(\.2).joined() + keyName
    }

    var carbonModifiers: UInt32 {
        var result = 0
        if modifiers.contains(.control) { result |= controlKey }
        if modifiers.contains(.option) { result |= optionKey }
        if modifiers.contains(.shift) { result |= shiftKey }
        if modifiers.contains(.command) { result |= cmdKey }
        return UInt32(result)
    }

    private var keyName: String {
        switch Int(keyCode) {
        case kVK_Space: "Space"
        case kVK_Return: "↩"
        case kVK_Escape: "⎋"
        case kVK_Tab: "⇥"
        default:
            Self.letters[Int(keyCode)] ?? "Key \(keyCode)"
        }
    }

    private static let letters: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F",
        kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R",
        kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
    ]
}
