import AppKit
import os

/// Runs the onboarding: the current page, where each permission stands, and
/// the actions behind the buttons. The explainer page always comes first;
/// the system dialog only on "Allow…".
@MainActor
@Observable
final class OnboardingModel {
    let flow: OnboardingFlow
    private(set) var page: OnboardingPage = .welcome {
        didSet {
            furthest = max(furthest, flow.index(of: page))
            onPageChange?(page)
        }
    }
    /// The furthest page reached; the dots go back to any page up to it.
    private(set) var furthest = 0
    /// Pages push in from the right going on, from the left going back.
    private(set) var forward = true
    private(set) var states: [OnboardingPermission: OnboardingPermissionState] = [:]
    /// A system dialog or the folder picker is up.
    private(set) var isAsking = false
    /// "Launch at login" on the last page; saved with "Let's go".
    var launchAtLogin = true

    @ObservationIgnored var onPageChange: ((OnboardingPage) -> Void)?
    @ObservationIgnored var onFinish: (() -> Void)?

    @ObservationIgnored private let calendar: CalendarManager
    @ObservationIgnored private let nowPlaying: NowPlayingManager
    @ObservationIgnored private let downloads: DownloadsManager
    @ObservationIgnored private let bluetooth: BluetoothManager

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Onboarding")

    init(calendar: CalendarManager, nowPlaying: NowPlayingManager, downloads: DownloadsManager, bluetooth: BluetoothManager) {
        self.calendar = calendar
        self.nowPlaying = nowPlaying
        self.downloads = downloads
        self.bluetooth = bluetooth
        flow = OnboardingFlow(spotifyInstalled: nowPlaying.isInstalled(.spotify))
        launchAtLogin = LaunchAtLogin.state != .disabled || !AppSettings.onboardingCompleted()
    }

    func state(of permission: OnboardingPermission) -> OnboardingPermissionState {
        states[permission] ?? .notAsked
    }

    /// Reads where every permission stands, without asking.
    func refreshStates() async {
        for permission in flow.permissions {
            states[permission] = await currentState(of: permission)
        }
    }

    func advance() {
        guard let next = flow.next(after: page) else { return }
        go(to: next)
    }

    /// A page dot: back to a page already seen (or forward up to the
    /// furthest one reached).
    func show(pageAt index: Int) {
        guard OnboardingModel.canShow(index, furthest: furthest, count: flow.pages.count), !isAsking else { return }
        go(to: flow.pages[index])
    }

    /// The direction is set first, on its own: the leaving page takes its
    /// transition from before the change.
    private func go(to target: OnboardingPage) {
        guard target != page else { return }
        let ahead = flow.index(of: target) > flow.index(of: page)
        guard ahead != forward else {
            page = target
            return
        }
        forward = ahead
        Task { @MainActor in self.page = target }
    }

    /// Trackpad swipe or mouse drag: fingers left go on (like Continue or
    /// Skip), right go back – as with the island's cards.
    func swipe(_ direction: SwipeDirection) {
        guard !isAsking else { return }
        let step = CardNavigation.step(forSwipe: direction)
        if step > 0 {
            advance()
        } else if step < 0 {
            let index = flow.index(of: page)
            if index > 0 { go(to: flow.pages[index - 1]) }
        }
    }

    nonisolated static func canShow(_ index: Int, furthest: Int, count: Int) -> Bool {
        (0..<count).contains(index) && index <= furthest
    }

    /// The system dialog (or folder picker), then on to the next page –
    /// whatever the answer.
    func allow(_ permission: OnboardingPermission) async {
        isAsking = true
        defer { isAsking = false }
        switch permission {
        case .calendar: await calendar.requestAccess()
        case .spotify: await nowPlaying.requestPermission(.spotify)
        case .music: await nowPlaying.requestPermission(.music)
        case .downloads: await downloads.chooseFolder()
        case .bluetooth: await bluetooth.requestAccess()
        }
        // The answer came from another app's dialog: be in front again.
        NSApp.activate()
        let state = await currentState(of: permission)
        states[permission] = state
        Self.logger.info("\(permission.rawValue, privacy: .public): \(String(describing: state), privacy: .public)")
        advance()
    }

    func openSystemSettings(for permission: OnboardingPermission) {
        let url: URL = switch permission {
        case .calendar: CalendarManager.settingsURL
        case .spotify, .music: NowPlayingManager.automationSettingsURL
        case .bluetooth: BluetoothManager.settingsURL
        case .downloads: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!
        }
        NSWorkspace.shared.open(url)
    }

    /// "Let's go": saves launch at login (asking for approval in Login
    /// Items if macOS wants it) and closes.
    func finish() {
        if LaunchAtLogin.set(launchAtLogin) == .needsApproval {
            LaunchAtLogin.openLoginItems()
        }
        onFinish?()
    }

    private func currentState(of permission: OnboardingPermission) async -> OnboardingPermissionState {
        switch permission {
        case .calendar:
            return Self.state(calendar.authorization == .granted, denied: calendar.authorization == .denied)
        case .bluetooth:
            return Self.state(bluetooth.access == .granted, denied: bluetooth.access == .denied)
        case .downloads:
            return downloads.access.folder != nil ? .granted : .notAsked
        case .spotify, .music:
            let player: MusicPlayer = permission == .spotify ? .spotify : .music
            let current = await nowPlaying.currentPermission(player)
            return Self.state(current == .granted, denied: current == .denied)
        }
    }

    private static func state(_ granted: Bool, denied: Bool) -> OnboardingPermissionState {
        granted ? .granted : denied ? .denied : .notAsked
    }
}
