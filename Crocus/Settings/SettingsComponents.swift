import SwiftUI

/// A command with a copy button (onboarding, Settings › Integrations).
struct CopyableCommand: View {
    let command: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Text(command)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Button(copied ? "Copied" : "Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copied = true
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// A coloured rounded square with a white symbol, like System Settings.
struct SettingsIcon: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// Records a global keyboard shortcut: click, press the keys (with at least
/// one of ⌃⌥⇧⌘), Esc cancels; ✕ removes it.
struct ShortcutRecorder: View {
    @AppStorage(AppSettings.Key.globalShortcut) private var stored = KeyboardShortcutSpec.default.stringValue
    @State private var recording = false
    @State private var monitor: Any?

    private var spec: KeyboardShortcutSpec? {
        stored.isEmpty ? nil : KeyboardShortcutSpec(string: stored) ?? .default
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(recording ? "Type shortcut…" : spec?.displayString ?? "None") {
                recording ? stop() : start()
            }
            .frame(minWidth: 110)
            .accessibilityLabel(recording ? "Recording shortcut" : "Shortcut \(spec?.displayString ?? "none"), click to change")
            if spec != nil, !recording {
                Button {
                    stored = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove shortcut")
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == 53 { // Esc
                stop()
            } else if let spec = KeyboardShortcutSpec(keyCode: event.keyCode, modifierFlags: event.modifierFlags) {
                stored = spec.stringValue
                stop()
            }
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
