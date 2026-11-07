import SwiftUI

/// The onboarding window's content (board 10): one page at a time, the
/// page dots and the buttons at the bottom. Pages change with a horizontal
/// push on `CrocusSprings.onboardingPage` while the content sharpens
/// (blur 4 → 0); Reduce Motion: 200 ms cross-fade.
struct OnboardingView: View {
    let model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                page(model.page)
                    .id(model.page)
                    .transition(.onboardingPage(forward: model.forward, reduceMotion: reduceMotion))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            HStack(spacing: 10) {
                OnboardingDots(
                    current: model.flow.index(of: model.page),
                    count: model.flow.pages.count,
                    furthest: model.furthest,
                    stepLabel: model.flow.windowTitle(for: model.page)
                ) { model.show(pageAt: $0) }
                Spacer()
                buttons(model.page)
            }
            .controlSize(.large)
            .disabled(model.isAsking)
        }
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .frame(width: 560, height: 440)
        // Click and drag sideways to go on or back (mice have no swipe).
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 12).onEnded { value in
            if let direction = CardDrag.direction(translation: value.translation) { model.swipe(direction) }
        })
        // No focus ring around the page when it is clicked.
        .focusEffectDisabled()
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : CrocusSprings.onboardingPage.animation, value: model.page)
        .task { await model.refreshStates() }
    }

    // MARK: - Pages

    @ViewBuilder
    private func page(_ page: OnboardingPage) -> some View {
        switch page {
        case .welcome:
            OnboardingPageContent(
                eyebrow: "Welcome",
                title: "Your notch can do more now",
                text: "Crocus shows what's going on right now: music, timers, events, builds. Click to open it, click anywhere else to close it.",
                checks: ["Also on external displays, as a floating pill"]
            ) {
                IslandDemoView()
            }
        case .permission(let permission):
            permissionPage(permission)
        case .shortcuts:
            OnboardingPageContent(
                eyebrow: "Your own activities",
                title: "Your own Live Activities",
                text: "Apps, scripts and shortcuts can send their own activities to the island: a title, symbol, progress, status and an action.",
                checks: [],
                footer: { CopyableCommand(command: #"open "crocus://start?id=build&title=Build&progress=0.4""#).frame(maxWidth: 440) }
            ) {
                OnboardingIcon(systemName: "square.stack.3d.up.fill", color: .indigo)
            }
        case .done:
            OnboardingPageContent(
                eyebrow: "Done",
                title: "You're all set",
                text: "Crocus now lives in your notch. Open its settings from the menu bar icon or with a right-click on the island.",
                checks: [],
                footer: { LaunchAtLoginToggle(isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 })) }
            ) {
                OnboardingIcon(systemName: "checkmark.circle.fill", color: .green)
            }
        }
    }

    private func permissionPage(_ permission: OnboardingPermission) -> some View {
        let copy = PermissionCopy(permission)
        return OnboardingPageContent(
            eyebrow: model.flow.counter(for: permission),
            title: copy.title,
            text: copy.text,
            checks: copy.checks,
            footer: { PermissionStatus(state: model.state(of: permission), denied: copy.denied) }
        ) {
            OnboardingIcon(systemName: copy.symbol, color: copy.color)
        }
    }

    // MARK: - Buttons

    @ViewBuilder
    private func buttons(_ page: OnboardingPage) -> some View {
        switch page {
        case .welcome:
            Button("Continue") { model.advance() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        case .permission(let permission):
            switch model.state(of: permission) {
            case .granted:
                Button("Continue") { model.advance() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            case .denied:
                Button("Open System Settings…") { model.openSystemSettings(for: permission) }
                Button("Continue") { model.advance() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            case .notAsked:
                if model.isAsking { ProgressView().controlSize(.small) }
                Button("Skip") { model.advance() }
                Button(PermissionCopy(permission).action) { Task { await model.allow(permission) } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        case .shortcuts:
            Button("Open Shortcuts") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
            }
            Button("Continue") { model.advance() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        case .done:
            Button("Let's go") { model.finish() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }
}

/// What each permission page says (board 10, in English like the app).
private struct PermissionCopy {
    let symbol: String
    let color: Color
    let title: String
    let text: String
    let checks: [String]
    let action: String
    /// Shown once it was denied: what is off now.
    let denied: String

    init(_ permission: OnboardingPermission) {
        switch permission {
        case .calendar:
            symbol = "calendar"; color = .red
            title = "Your next event at a glance"
            text = "Crocus shows your next event 5 minutes before it starts and spots video call links so you can join right away. macOS asks next."
            checks = ["Only events in the next 24 hours", "Everything stays on your Mac"]
            action = "Allow Access…"
            denied = "Calendar events stay off."
        case .spotify:
            symbol = "music.note"; color = .green
            title = "Control Spotify"
            text = "So Crocus can show the current track and play, pause and skip, macOS asks next whether Crocus may control Spotify."
            checks = ["No sign-in needed", "Only the current track"]
            action = "Allow…"
            denied = "Spotify stays off in the island."
        case .music:
            symbol = "music.note"; color = .pink
            title = "Control Apple Music"
            text = "macOS asks next whether Crocus may control the Music app. Cover, title and controls then show in the island."
            checks = ["Only the current track, never your library", "Change it any time in System Settings"]
            action = "Allow…"
            denied = "Music stays off in the island."
        case .downloads:
            symbol = "tray.and.arrow.down.fill"; color = .blue
            title = "Follow your downloads"
            text = "Choose your Downloads folder once. Crocus then shows the progress of running downloads."
            checks = ["Only this folder, only file names and sizes", "The App Sandbox needs you to pick it"]
            action = "Choose Folder…"
            denied = "Downloads stay off."
        case .bluetooth:
            symbol = "headphones"; color = .blue
            title = "See devices connect"
            text = "Crocus briefly shows when headphones, a mouse or a keyboard connects or disconnects, with its battery level when there is one. macOS asks next."
            checks = ["Only connections and battery levels", "Everything stays on your Mac"]
            action = "Allow…"
            denied = "Bluetooth events stay off."
        }
    }
}

// MARK: - Building blocks

/// Icon (or demo), eyebrow, title, text, check list and an optional footer –
/// read by VoiceOver in that order, before the buttons.
private struct OnboardingPageContent<Header: View, Footer: View>: View {
    let eyebrow: String
    let title: String
    let text: String
    let checks: [String]
    @ViewBuilder var footer: Footer
    @ViewBuilder var header: Header

    init(
        eyebrow: String, title: String, text: String, checks: [String],
        @ViewBuilder footer: () -> Footer = { EmptyView() },
        @ViewBuilder header: () -> Header
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.text = text
        self.checks = checks
        self.footer = footer()
        self.header = header()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 112)
                .padding(.bottom, 22)
            Text(eyebrow.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 10)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
                .padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(checks, id: \.self) { check in
                    Label {
                        Text(check)
                    } icon: {
                        Image(systemName: "checkmark").foregroundStyle(.green).fontWeight(.semibold)
                    }
                    .font(.system(size: 12))
                }
            }
            footer
                .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// The permission's symbol on a white tile.
private struct OnboardingIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .frame(width: 80, height: 80)
            .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)
    }
}

/// Granted or denied, shown once the permission was answered.
private struct PermissionStatus: View {
    let state: OnboardingPermissionState
    let denied: String

    var body: some View {
        switch state {
        case .notAsked:
            EmptyView()
        case .granted:
            Label("Allowed", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.green)
        case .denied:
            Text("\(denied) You can allow it later in System Settings.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

private struct LaunchAtLoginToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("Launch at login", isOn: $isOn)
            .toggleStyle(.checkbox)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// One dot per page: done pages filled blue, the current one a longer blue
/// capsule, the ones still to come grey – progress at a glance. A click
/// goes to a page already seen.
private struct OnboardingDots: View {
    let current: Int
    let count: Int
    let furthest: Int
    let stepLabel: String
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                let reachable = OnboardingModel.canShow(index, furthest: furthest, count: count)
                Capsule()
                    .fill(index <= current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 22 : 7, height: 7)
                    // Easy to hit, though the dots sit close together.
                    .padding(.horizontal, 3)
                    .frame(height: 22)
                    .contentShape(Rectangle())
                    .onTapGesture { if reachable { onSelect(index) } }
            }
        }
        .animation(CrocusSprings.onboardingPage.animation, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
        .accessibilityValue(stepLabel)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onSelect(current + 1)
            case .decrement: onSelect(current - 1)
            @unknown default: break
            }
        }
    }
}

/// The page push: the new page comes in from the right and sharpens, the
/// old one leaves to the left.
private struct OnboardingPush: ViewModifier {
    let offset: CGFloat
    let blur: CGFloat

    func body(content: Content) -> some View {
        content.offset(x: offset).blur(radius: blur)
    }
}

private extension AnyTransition {
    static func onboardingPage(forward: Bool, reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        let width: CGFloat = forward ? 560 : -560
        return .asymmetric(
            insertion: .modifier(active: OnboardingPush(offset: width, blur: 4), identity: OnboardingPush(offset: 0, blur: 0)),
            removal: .modifier(active: OnboardingPush(offset: -width, blur: 4), identity: OnboardingPush(offset: 0, blur: 0))
        )
    }
}
