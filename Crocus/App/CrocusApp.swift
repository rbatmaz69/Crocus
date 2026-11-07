import SwiftUI

/// Crocus runs as a menu bar agent (`LSUIElement = YES`): no Dock icon and no
/// main window. The menu bar icon and its panel come from
/// `MenuBarController` (#61), the island from `OverlayController`.
@main
struct CrocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(app: appDelegate)
        }
        .windowResizability(.contentSize)
    }
}

#if DEBUG
struct DebugMenu: View {
    @Bindable var overlay: OverlayController
    let store: IslandStore
    let power: PowerManager
    let bluetooth: BluetoothManager
    @AppStorage(AppSettings.Key.debugSlowAnimations) private var slowAnimations = false

    var body: some View {
        Toggle("Show Overlay Frames", isOn: $overlay.showsDebugFrame)
        Toggle("Slow Animations (5×)", isOn: $slowAnimations)
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
            Button("Simulate Plug-In") { power.show(.pluggedIn(level: 82)) }
            Button("Simulate 10 % Battery") { power.show(.lowBattery(level: 10)) }
            Button("Simulate 5 % Battery") { power.show(.lowBattery(level: 5)) }
            Button("Simulate AirPods Connect") { bluetooth.show(.airPods, name: "AirPods", connected: true) }
            Button("Simulate Headphones Disconnect") { bluetooth.show(.headphones, name: "Headphones", connected: false) }
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






