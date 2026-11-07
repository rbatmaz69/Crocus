import SwiftUI

/// The settings window (board 11): 680 × 500, a sidebar of five sections
/// and grouped forms like System Settings. Every change applies at once.
struct SettingsView: View {
    let app: AppDelegate
    @State private var section: SettingsSection? = .general

    var body: some View {
        // Like System Settings: the sidebar always shows (collapsing it made
        // the forms re-fit in a jump when it came back).
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SettingsSection.allCases, selection: $section) { section in
                Label {
                    Text(section.title)
                } icon: {
                    SettingsIcon(systemName: section.symbol, color: section.color)
                }
                .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch section ?? .general {
                case .general: GeneralSettings()
                case .activities: ActivitySettings(app: app)
                case .appearance: AppearanceSettings()
                case .integrations: IntegrationSettings(nowPlaying: app.nowPlaying)
                case .about: AboutSettings()
                }
            }
            .navigationTitle((section ?? .general).title)
        }
        .frame(width: 680, height: 500)
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, activities, appearance, integrations, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .activities: "Activities"
        case .appearance: "Appearance"
        case .integrations: "Integrations"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .activities: "square.stack.fill"
        case .appearance: "paintbrush.fill"
        case .integrations: "puzzlepiece.extension.fill"
        case .about: "info"
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .activities: .orange
        case .appearance: .blue
        case .integrations: .indigo
        case .about: .gray
        }
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @AppStorage(AppSettings.Key.targetScreen) private var targetScreen = TargetScreenOption.automatic
    @AppStorage(AppSettings.Key.animateScreenChange) private var animateScreenChange = true
    @AppStorage(AppSettings.Key.hideDuringFullScreenVideo) private var hideDuringFullScreenVideo = true
    @AppStorage(AppSettings.Key.hoverStyle) private var hoverStyle = HoverStyle.breathe
    @State private var launchAtLogin = LaunchAtLogin.state

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin != .disabled },
                    set: { launchAtLogin = LaunchAtLogin.set($0) }
                ))
                if launchAtLogin == .needsApproval {
                    LabeledContent("Allow Crocus in Login Items to start it at login.") {
                        Button("Open Login Items…") { LaunchAtLogin.openLoginItems() }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            Section {
                Picker("Show island on", selection: $targetScreen) {
                    ForEach(TargetScreenOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                Toggle("Animate screen change", isOn: $animateScreenChange)
                Toggle("Hide during full-screen videos", isOn: $hideDuringFullScreenVideo)
            }
            Section {
                Picker("On hover", selection: $hoverStyle) {
                    ForEach(HoverStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Hovering never opens the island. Open it with a click or a swipe down.")
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Keyboard shortcut") { ShortcutRecorder() }
            } footer: {
                Text("Opens and closes the island from anywhere.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = LaunchAtLogin.state }
    }
}

// MARK: - Activities

private struct ActivitySettings: View {
    let app: AppDelegate
    @State private var priority = AppSettings.activityPriority()
    @State private var disabled = AppSettings.disabledActivities()
    @State private var disabledEvents = AppSettings.disabledEvents()

    private static let batteryEvents: Set<EventKind> = [.charging, .lowBattery]

    var body: some View {
        List {
            Section {
                row(.cameraMicrophone, movable: false)
                ForEach(priority.movable, id: \.self) { kind in
                    row(kind, movable: true)
                }
                .onMove { source, destination in
                    priority = priority.moving(fromOffsets: source, toOffset: destination)
                    AppSettings.setActivityPriority(priority)
                }
                eventRow(title: "Charging and battery", symbol: "bolt.fill", color: .teal, kinds: Self.batteryEvents) { EmptyView() }
                eventRow(title: "Bluetooth", symbol: "headphones", color: .blue, kinds: [.bluetooth]) {
                    BluetoothHint(bluetooth: app.bluetooth)
                }
            } footer: {
                Text("Drag to change the priority. Camera and microphone always stay on top for your privacy. Charging, battery and Bluetooth are short events and have no position.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 6)
    }

    private func row(_ kind: ActivityKind, movable: Bool) -> some View {
        let style = ActivityStyle(kind)
        return SettingsActivityRow(
            title: style.title, symbol: style.symbol, color: style.color, detail: style.detail, movable: movable,
            isOn: Binding(
                get: { !disabled.contains(kind) },
                set: { on in
                    AppSettings.setActivity(kind, enabled: on)
                    disabled = AppSettings.disabledActivities()
                }
            )
        ) {
            switch kind {
            case .calendar: CalendarHint(calendar: app.calendar)
            case .music: MusicHint(nowPlaying: app.nowPlaying)
            case .download: DownloadsHint(downloads: app.downloads)
            case .cameraMicrophone, .timer, .liveActivity: EmptyView()
            }
        }
        .accessibilityActions {
            if movable {
                Button("Move up") { move(kind, by: -1) }
                Button("Move down") { move(kind, by: 1) }
            }
        }
    }

    private func eventRow(title: String, symbol: String, color: Color, kinds: Set<EventKind>, @ViewBuilder hint: () -> some View) -> some View {
        SettingsActivityRow(
            title: title, symbol: symbol, color: color, detail: "Event", movable: false,
            isOn: Binding(
                get: { disabledEvents.isDisjoint(with: kinds) },
                set: { on in
                    AppSettings.setEvents(kinds, enabled: on)
                    disabledEvents = AppSettings.disabledEvents()
                }
            ),
            hint: hint
        )
    }

    private func move(_ kind: ActivityKind, by step: Int) {
        guard let index = priority.movable.firstIndex(of: kind) else { return }
        let target = index + step
        guard priority.movable.indices.contains(target) else { return }
        priority = priority.moving(fromOffsets: [index], toOffset: step > 0 ? target + 1 : target)
        AppSettings.setActivityPriority(priority)
    }
}

/// Name, symbol and short note for each activity type.
private struct ActivityStyle {
    let title: String
    let symbol: String
    let color: Color
    let detail: String

    init(_ kind: ActivityKind) {
        switch kind {
        case .cameraMicrophone: (title, symbol, color, detail) = ("Camera and microphone", "video.fill", .green, "Fixed on top")
        case .calendar: (title, symbol, color, detail) = ("Calendar", "calendar", .red, "5 min before")
        case .timer: (title, symbol, color, detail) = ("Timer and stopwatch", "timer", .orange, "")
        case .liveActivity: (title, symbol, color, detail) = ("Live Activities", "square.stack.3d.up.fill", .indigo, "Shortcuts, URL")
        case .download: (title, symbol, color, detail) = ("Downloads", "arrow.down", .blue, "")
        case .music: (title, symbol, color, detail) = ("Music", "music.note", .pink, "Spotify, Apple Music")
        }
    }
}

private struct SettingsActivityRow<Hint: View>: View {
    let title: String
    let symbol: String
    let color: Color
    let detail: String
    let movable: Bool
    @Binding var isOn: Bool
    @ViewBuilder var hint: Hint

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .opacity(movable ? 1 : 0)
                .accessibilityHidden(true)
            SettingsIcon(systemName: symbol, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                hint
            }
            Spacer()
            if !detail.isEmpty {
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(minHeight: 30)
        .padding(.vertical, 2)
    }
}

// MARK: Permission hints (activities that need one)

private struct CalendarHint: View {
    let calendar: CalendarManager

    var body: some View {
        switch calendar.authorization {
        case .granted: EmptyView()
        case .notDetermined:
            HintButton("Not allowed yet – Allow…") { Task { await calendar.requestAccess() } }
        case .denied:
            HintButton("Not allowed – Open System Settings…") { NSWorkspace.shared.open(CalendarManager.settingsURL) }
        }
    }
}

private struct BluetoothHint: View {
    let bluetooth: BluetoothManager

    var body: some View {
        switch bluetooth.access {
        case .granted: EmptyView()
        case .notDetermined:
            HintButton("Not allowed yet – Allow…") { Task { await bluetooth.requestAccess() } }
        case .denied:
            HintButton("Not allowed – Open System Settings…") { NSWorkspace.shared.open(BluetoothManager.settingsURL) }
        }
    }
}

private struct DownloadsHint: View {
    let downloads: DownloadsManager

    var body: some View {
        if let folder = downloads.access.folder {
            HintButton("Folder: \(folder.lastPathComponent) – Change…") { Task { await downloads.chooseFolder() } }
        } else {
            HintButton("No folder chosen – Choose Folder…") { Task { await downloads.chooseFolder() } }
        }
    }
}

private struct MusicHint: View {
    let nowPlaying: NowPlayingManager

    var body: some View {
        let players = MusicPlayer.allCases.filter { nowPlaying.isInstalled($0) }
        ForEach(players, id: \.self) { player in
            switch nowPlaying.permissions[player] {
            case .denied:
                HintButton("\(player.displayName) not allowed – Open System Settings…") {
                    NSWorkspace.shared.open(NowPlayingManager.automationSettingsURL)
                }
            case .notDetermined:
                HintButton("\(player.displayName) not allowed yet – Allow…") { Task { await nowPlaying.requestPermission(player) } }
            case .granted, .unavailable, nil:
                EmptyView()
            }
        }
        .task {
            for player in players { await nowPlaying.refreshPermission(player) }
        }
    }
}

private struct HintButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.link)
            .font(.callout)
    }
}

// MARK: - Appearance

private struct AppearanceSettings: View {
    @AppStorage(AppSettings.Key.textSize) private var textSize = TextSizeAdjustment.standard
    @AppStorage(AppSettings.Key.hapticFeedback) private var hapticFeedback = true
    @AppStorage(AppSettings.Key.animationStrength) private var strength = MotionStrength.standard

    var body: some View {
        Form {
            Section {
                IslandDemoView(scene: .timer, size: CGSize(width: 420, height: 92), scale: 0.78)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .bottomLeading) {
                        Text("Live preview")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(8)
                    }
            }
            Section {
                Picker("Size", selection: $textSize) {
                    ForEach(TextSizeAdjustment.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Haptic feedback (Force Touch)", isOn: $hapticFeedback)
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Animation strength") { Text(strength.title).foregroundStyle(.secondary) }
                    Slider(
                        value: Binding(get: { strength.sliderValue }, set: { strength = MotionStrength(sliderValue: $0) }),
                        in: 0...2, step: 1
                    )
                    .labelsHidden()
                    .accessibilityLabel("Animation strength")
                    .accessibilityValue(strength.title)
                    HStack {
                        Text("Subtle")
                        Spacer()
                        Text("Lively")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } footer: {
                Text("“Reduce motion” in Accessibility settings always wins: then the island only cross-fades.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Integrations

private struct IntegrationSettings: View {
    let nowPlaying: NowPlayingManager

    var body: some View {
        Form {
            Section("Shortcuts actions") {
                IntegrationAction(name: "Start Activity", text: "title, symbol, progress 0–1, status, optional action")
                IntegrationAction(name: "Update Progress", text: "new value and status for a running activity")
                IntegrationAction(name: "End Activity", text: "with the result Succeeded, Failed or Cancelled")
            }
            Section {
                CopyableCommand(command: #"open "crocus://start?id=build&title=Build&symbol=hammer&progress=0.4""#)
            } header: {
                Text("URL scheme")
            } footer: {
                Text("More commands: crocus://update and crocus://end – the parameters are in the README.")
                    .foregroundStyle(.secondary)
            }
            Section("Music players") {
                ForEach(MusicPlayer.allCases.filter { nowPlaying.isInstalled($0) }, id: \.self) { player in
                    LabeledContent("Control \(player.displayName)") {
                        PlayerPermissionStatus(player: player, nowPlaying: nowPlaying)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            for player in MusicPlayer.allCases where nowPlaying.isInstalled(player) {
                await nowPlaying.refreshPermission(player)
            }
        }
    }
}

private struct IntegrationAction: View {
    let name: String
    let text: String

    var body: some View {
        (Text(name).fontWeight(.semibold) + Text(" – \(text)").foregroundStyle(.secondary))
            .font(.callout)
    }
}

private struct PlayerPermissionStatus: View {
    let player: MusicPlayer
    let nowPlaying: NowPlayingManager

    var body: some View {
        switch nowPlaying.permissions[player] {
        case .granted:
            Text("Allowed").foregroundStyle(.green)
        case .denied:
            Button("Open System Settings…") { NSWorkspace.shared.open(NowPlayingManager.automationSettingsURL) }
        case .notDetermined, .unavailable, nil:
            Button("Allow…") { Task { await nowPlaying.requestPermission(player) } }
        }
    }
}

// MARK: - About

private struct AboutSettings: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("Crocus").font(.title).fontWeight(.bold)
            Text(version).foregroundStyle(.secondary)
            Text("Crocus collects no data. Everything the island shows stays on your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 340)
                .padding(.top, 4)
            HStack(spacing: 18) {
                Link("Privacy", destination: URL(string: "https://github.com/rbatmaz69/Crocus#readme")!)
                Link("Support", destination: URL(string: "https://github.com/rbatmaz69/Crocus/issues")!)
            }
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
