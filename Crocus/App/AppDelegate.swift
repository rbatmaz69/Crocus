import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let router = URLRouter()
    let overlay = OverlayController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Don't put windows on screen while running as a unit test host.
        guard !Self.isRunningTests else { return }
        overlay.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlay.stop()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            router.handle(url)
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
