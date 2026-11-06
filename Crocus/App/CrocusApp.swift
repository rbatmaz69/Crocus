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

            Divider()
            TimerMenu(timers: appDelegate.timers)
            NowPlayingPermissionHint(nowPlaying: appDelegate.nowPlaying)
            CalendarAccessMenu(calendar: appDelegate.calendar)

            #if DEBUG
            Divider()
            DebugMenu(overlay: appDelegate.overlay, store: appDelegate.store, power: appDelegate.power)
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
    let power: PowerManager
    @AppStorage(AppSettings.Key.targetScreen) private var targetScreen = TargetScreenOption.automatic
    @AppStorage(AppSettings.Key.hoverStyle) private var hoverStyle = HoverStyle.breathe

    var body: some View {
        Toggle("Show Overlay Frames", isOn: $overlay.showsDebugFrame)
        Picker("Hover Style", selection: $hoverStyle) {
            ForEach(HoverStyle.allCases) { style in
                Text(style.title).tag(style)
            }
        }
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
            Button("Simulate Plug-In") { power.show(.pluggedIn(level: 82)) }
            Button("Simulate 10 % Battery") { power.show(.lowBattery(level: 10)) }
            Button("Simulate 5 % Battery") { power.show(.lowBattery(level: 5)) }
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

/// Start a timer or the stopwatch; pause, resume or stop them.
private struct TimerMenu: View {
    let timers: TimerManager

    static let presets: [Int] = [1, 5, 10, 15, 25]

    var body: some View {
        Menu("Timer") {
            ForEach(Self.presets, id: \.self) { minutes in
                Button("\(minutes) min") { timers.startTimer(duration: TimeInterval(minutes * 60)) }
            }
            Button("Stopwatch") { timers.startStopwatch() }
            ForEach(TimerState.Kind.allCases, id: \.self) { kind in
                if let state = timers.state(kind) {
                    Divider()
                    let title = TimerFormat.title(kind)
                    if state.isRunning {
                        Button("Pause \(title)") { timers.pause(kind) }
                    } else if state.isPaused {
                        Button("Resume \(title)") { timers.resume(kind) }
                    }
                    Button("Stop \(title)") { timers.stop(kind) }
                }
            }
        }
    }
}

/// Shown only when a player isn't allowed: how to turn it back on.
private struct NowPlayingPermissionHint: View {
    let nowPlaying: NowPlayingManager

    var body: some View {
        let denied = MusicPlayer.allCases.filter { nowPlaying.permissions[$0] == .denied }
        if !denied.isEmpty {
            Divider()
            Text("Now Playing is off for \(denied.map(\.displayName).joined(separator: " and "))")
            Button("Allow in System Settings…") { NSWorkspace.shared.open(NowPlayingManager.automationSettingsURL) }
        }
    }
}

/// Calendar access until onboarding (#26) asks for it: allow, or how to
/// turn it back on.
private struct CalendarAccessMenu: View {
    let calendar: CalendarManager

    var body: some View {
        switch calendar.authorization {
        case .granted:
            EmptyView()
        case .notDetermined:
            Divider()
            Button("Allow Calendar…") {
                NSApp.activate()
                Task { await calendar.requestAccess() }
            }
        case .denied:
            Divider()
            Text("Calendar events are off")
            Button("Allow in System Settings…") { NSWorkspace.shared.open(CalendarManager.settingsURL) }
        }
    }
}

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
