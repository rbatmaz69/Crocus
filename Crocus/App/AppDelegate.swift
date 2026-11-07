import AppIntents
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let router = URLRouter()
    let store = IslandStore()
    lazy var overlay = OverlayController(store: store)
    lazy var liveActivities = LiveActivityManager(store: store)
    lazy var timers = TimerManager(store: store)
    lazy var nowPlaying = NowPlayingManager(store: store)
    lazy var power = PowerManager(store: store)
    lazy var calendar = CalendarManager(store: store)
    lazy var privacy = PrivacyManager(store: store)
    lazy var downloads = DownloadsManager(store: store)
    lazy var bluetooth = BluetoothManager(store: store)
    lazy var menuBar = MenuBarController(app: self)
    lazy var onboarding = OnboardingWindowController { [unowned self] in
        OnboardingModel(calendar: calendar, nowPlaying: nowPlaying, downloads: downloads, bluetooth: bluetooth)
    }

    /// Permissions and setup the menu bar panel asks for (#61); while any is
    /// missing, the menu bar icon carries a dot.
    var menuBarAttention: [MenuBarAttentionItem] {
        MenuBarAttention.items(
            calendar: calendar.authorization,
            players: nowPlaying.permissions.filter { nowPlaying.isInstalled($0.key) },
            bluetooth: bluetooth.access,
            downloadsFolder: downloads.access.folder,
            disabledActivities: AppSettings.disabledActivities(),
            disabledEvents: AppSettings.disabledEvents()
        )
    }

    /// The app that was frontmost before Crocus; `open crocus://…` activates
    /// Crocus, and focus goes back there afterwards.
    private var previousApp: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?

    override init() {
        super.init()
        // Registered before launch finishes: Shortcuts may start Crocus just
        // to run an intent.
        let liveActivities = liveActivities
        AppDependencyManager.shared.add { liveActivities }
        let timers = timers
        AppDependencyManager.shared.add { timers }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Don't put windows on screen while running as a unit test host.
        guard !Self.isRunningTests else { return }
        overlay.start()
        menuBar.start()
        timers.start()
        nowPlaying.start()
        power.start()
        calendar.start()
        privacy.start()
        downloads.start()
        bluetooth.start()
        trackFrontmostApp()
        // First launch: set up with an explainer before every permission.
        if !AppSettings.onboardingCompleted() { onboarding.show() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBar.stop()
        overlay.stop()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if case .liveActivity(let command) = router.handle(url) {
                liveActivities.handle(command)
            }
        }
        returnFocus()
    }

    /// Hands focus back to the previous app unless one of Crocus' own windows
    /// (e.g. Settings) is open, so a script calling `open crocus://…` doesn't
    /// steal the keyboard from the Terminal. Also after the menu bar panel
    /// closes: while Crocus stays active without a window, no mouse moves
    /// reach `MouseTracker` and the island stops reacting (#61).
    func returnFocus() {
        guard NSApp.isActive else { return }
        let hasOwnWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain }
        guard !hasOwnWindow, let previousApp, !previousApp.isTerminated else { return }
        previousApp.activate()
    }

    private func trackFrontmostApp() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ownPID {
            previousApp = front
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let app, app.processIdentifier != ownPID else { return }
                self?.previousApp = app
            }
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
