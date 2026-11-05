import SwiftUI

/// Crocus runs as a menu bar agent (`LSUIElement = YES`): no Dock icon and no
/// main window. The island overlay itself is added in later issues (#3).
@main
struct CrocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Crocus", systemImage: "capsule.fill") {
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")

            #if DEBUG
            Divider()
            DebugMenu(overlay: appDelegate.overlay, store: appDelegate.store)
            #endif

            Divider()

            Button("Quit Crocus") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsPlaceholderView()
        }
    }
}

#if DEBUG
private struct DebugMenu: View {
    @Bindable var overlay: OverlayController
    let store: IslandStore
    @AppStorage(AppSettings.Key.targetScreen) private var targetScreen = TargetScreenOption.automatic

    var body: some View {
        Toggle("Show Overlay Frames", isOn: $overlay.showsDebugFrame)
        Toggle("Overlay Accepts Keyboard", isOn: $overlay.acceptsKeyboard)
        Picker("Target Screen", selection: $targetScreen) {
            ForEach(TargetScreenOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        Menu("Activities") {
            ForEach(ActivityKind.allCases, id: \.self) { kind in
                Toggle(SampleActivities.make(kind).title, isOn: Binding(
                    get: { store.activities["sample.\(kind.rawValue)"] != nil },
                    set: { on in
                        if on { store.upsert(SampleActivities.make(kind)) } else { store.remove(id: "sample.\(kind.rawValue)") }
                    }
                ))
            }
            Divider()
            Button("Send Charging Event") { store.post(SampleActivities.chargingEvent) }
            Button("Send Bluetooth Event") { store.post(SampleActivities.bluetoothEvent) }
            Divider()
            Button("Expand") { store.expand() }
            Button("Collapse") { store.collapse() }
            Button("End All") { store.removeAll() }
        }
        Picker("Pill Outline", selection: $overlay.pillOutlineOverride) {
            ForEach(PillOutlineOverride.allCases) { option in
                Text(option.title).tag(option)
            }
        }
    }
}
#endif

/// Placeholder until the real settings window lands (#27).
private struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "capsule.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Crocus")
                .font(.title2.weight(.semibold))
            Text("Settings are coming soon.")
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 360)
    }
}
