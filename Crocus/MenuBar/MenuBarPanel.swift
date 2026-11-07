import AppKit
import SwiftUI

/// The panel behind the crocus in the menu bar (#61, board G), shown in a
/// popover by `MenuBarController`: the running activities, a quick timer,
/// missing permissions and the usual Settings / Quit.
struct MenuBarPanel: View {
    let app: AppDelegate
    let menuBar: MenuBarController
    @AppStorage(AppSettings.Key.islandHidden) private var islandHidden = false
    @AppStorage(AppSettings.Key.targetScreen) private var targetScreen = TargetScreenOption.automatic
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let activities = app.store.cardActivities
        let attention = app.menuBarAttention

        VStack(alignment: .leading, spacing: 14) {
            header(activityCount: activities.count)

            if !activities.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    MenuBarSectionLabel(title: "Now")
                    MenuBarGroup {
                        ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                            if index > 0 { MenuBarSeparator() }
                            ActivityRow(activity: activity)
                        }
                    }
                }
            }

            if !attention.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    MenuBarSectionLabel(title: "Needs your permission", trailing: "\(attention.count)")
                    MenuBarGroup {
                        ForEach(Array(attention.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { MenuBarSeparator() }
                            attentionRow(item)
                        }
                    }
                }
            }

            quickTimer
            screenPicker
            footer

            #if DEBUG
            DeveloperSection(app: app)
            #endif
        }
        .padding(MenuBarMetrics.padding)
        .padding(.top, 4)
        .frame(width: MenuBarMetrics.panelWidth)
        .onExitCommand { menuBar.close() }
    }

    // MARK: - Header

    private func header(activityCount: Int) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Crocus").font(.system(size: 13, weight: .semibold))
                Text(MenuBarStatus.line(activityCount: activityCount, screenName: app.overlay.targetScreenName, islandHidden: islandHidden))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Toggle("Show island", isOn: Binding(get: { !islandHidden }, set: { islandHidden = !$0 }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .help("Show island")
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Permissions

    private func attentionRow(_ item: MenuBarAttentionItem) -> some View {
        MenuBarRow(symbol: item.symbol, tint: item.tint, title: item.title) {
            MenuBarDetail(text: item.detail)
        } trailing: {
            MenuBarPillButton(title: item.buttonTitle, prominent: item.action == .request) { perform(item) }
                .accessibilityLabel("\(item.buttonTitle.trimmingCharacters(in: CharacterSet(charactersIn: "…"))) \(item.title)")
        }
    }

    private func perform(_ item: MenuBarAttentionItem) {
        // Asking or the folder picker needs Crocus in front; the others hand
        // focus on to System Settings anyway.
        menuBar.close(returningFocus: item.action == .openSystemSettings)
        switch (item.subject, item.action) {
        case (.calendar, .request):
            NSApp.activate()
            Task { await app.calendar.requestAccess() }
        case (.calendar, _):
            NSWorkspace.shared.open(CalendarManager.settingsURL)
        case (.player(let player), .request):
            NSApp.activate()
            Task { await app.nowPlaying.requestPermission(player) }
        case (.player, _):
            NSWorkspace.shared.open(NowPlayingManager.automationSettingsURL)
        case (.bluetooth, .request):
            NSApp.activate()
            Task { await app.bluetooth.requestAccess() }
        case (.bluetooth, _):
            NSWorkspace.shared.open(BluetoothManager.settingsURL)
        case (.downloadsFolder, _):
            Task { await app.downloads.chooseFolder() }
        }
    }

    // MARK: - Timer

    private var quickTimer: some View {
        VStack(alignment: .leading, spacing: 6) {
            MenuBarSectionLabel(title: "Start timer", trailing: "Minutes")
            HStack(spacing: 6) {
                ForEach(MenuBarPanel.timerPresets, id: \.self) { minutes in
                    chip(accessibilityLabel: "\(minutes) minute timer") {
                        app.timers.startTimer(duration: TimeInterval(minutes * 60))
                    } label: {
                        Text("\(minutes)").monospacedDigit()
                    }
                }
                chip(accessibilityLabel: "Stopwatch") {
                    app.timers.startStopwatch()
                } label: {
                    Image(systemName: "stopwatch")
                }
            }
        }
    }

    static let timerPresets = [1, 5, 10, 15, 25]

    private func chip(accessibilityLabel: String, action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button {
            action()
            menuBar.close()
        } label: {
            label()
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: MenuBarMetrics.hitSize)
                .background(Capsule().fill(.quaternary))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Screen

    private var screenPicker: some View {
        MenuBarGroup {
            HStack(spacing: 10) {
                Image(systemName: "display")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: MenuBarMetrics.tileSize)
                    .accessibilityHidden(true)
                Picker("Island on", selection: $targetScreen) {
                    ForEach(TargetScreenOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 13))
            }
            .padding(.horizontal, MenuBarMetrics.padding)
            .frame(minHeight: 36)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 4).padding(.bottom, 4)
            FooterButton(title: "Set Up Crocus…") {
                menuBar.close(returningFocus: false)
                app.onboarding.show()
            }
            FooterButton(title: "Settings…", shortcut: "⌘,") {
                menuBar.close(returningFocus: false)
                NSApp.activate()
                openSettings()
            }
            .keyboardShortcut(",")
            FooterButton(title: "Quit Crocus", shortcut: "⌘Q") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

/// One row under "Now".
private struct ActivityRow: View {
    let activity: any IslandActivity

    var body: some View {
        MenuBarRow(symbol: activity.panelSymbol, tint: activity.panelTint, title: activity.panelTitle) {
            activity.panelDetail
        } trailing: {
            HStack(spacing: 6) { activity.panelControls }
        }
    }
}

/// Footer entry styled like a menu item, with its shortcut on the right.
private struct FooterButton: View {
    let title: String
    var shortcut: String?
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 13))
                Spacer()
                if let shortcut {
                    Text(shortcut).font(.system(size: 12)).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, MenuBarMetrics.padding)
            .frame(minHeight: MenuBarMetrics.footerRowHeight)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(hovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

#if DEBUG
/// The former debug menu, collapsed at the bottom of debug builds.
private struct DeveloperSection: View {
    let app: AppDelegate
    @State private var expanded = false

    var body: some View {
        DisclosureGroup("Developer", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                DebugMenu(overlay: app.overlay, store: app.store, power: app.power, bluetooth: app.bluetooth)
            }
            .controlSize(.small)
            .padding(.top, 6)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }
}
#endif
