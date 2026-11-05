import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let router = URLRouter()

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            router.handle(url)
        }
    }
}
