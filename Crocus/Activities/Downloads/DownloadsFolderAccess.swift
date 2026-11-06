import AppKit
import os

/// The downloads folder the user picked once, kept as a security-scoped
/// bookmark so the sandbox lets Crocus read it after a relaunch too.
@MainActor
@Observable
final class DownloadsFolderAccess {
    /// Turns a folder into bookmark data and back; injectable for tests.
    struct Bookmarks: Sendable {
        var make: @Sendable (URL) throws -> Data
        var resolve: @Sendable (Data) throws -> (url: URL, isStale: Bool)
        var startAccessing: @Sendable (URL) -> Bool
        var stopAccessing: @Sendable (URL) -> Void

        static let securityScoped = Bookmarks(
            make: { try $0.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil) },
            resolve: { data in
                var stale = false
                let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
                return (url, stale)
            },
            startAccessing: { $0.startAccessingSecurityScopedResource() },
            stopAccessing: { $0.stopAccessingSecurityScopedResource() }
        )
    }

    /// The folder, readable while set.
    private(set) var folder: URL?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let bookmarks: Bookmarks
    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Downloads")

    init(defaults: UserDefaults = .standard, bookmarks: Bookmarks = .securityScoped) {
        self.defaults = defaults
        self.bookmarks = bookmarks
    }

    /// The real ~/Downloads (in the sandbox, the home directory is the
    /// container's).
    static var userDownloads: URL {
        let home = getpwuid(getuid())?.pointee.pw_dir.map { String(cString: $0) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home).appending(path: "Downloads", directoryHint: .isDirectory)
    }

    /// Opens the bookmarked folder; `nil` without one or if it is gone.
    @discardableResult
    func restore() -> URL? {
        guard let data = defaults.data(forKey: AppSettings.Key.downloadsBookmark) else { return nil }
        do {
            let (url, isStale) = try bookmarks.resolve(data)
            guard bookmarks.startAccessing(url) else {
                Self.logger.error("No access to the bookmarked folder")
                return nil
            }
            if isStale, let fresh = try? bookmarks.make(url) {
                defaults.set(fresh, forKey: AppSettings.Key.downloadsBookmark)
                Self.logger.info("Renewed the folder bookmark")
            }
            set(url)
            return url
        } catch {
            Self.logger.error("Folder bookmark no longer resolves: \(error.localizedDescription, privacy: .public)")
            defaults.removeObject(forKey: AppSettings.Key.downloadsBookmark)
            return nil
        }
    }

    /// Asks the user for the folder (menu bar: "Choose Downloads Folder…").
    func choose() async {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = Self.userDownloads
        panel.prompt = "Choose"
        panel.message = "Crocus shows the progress of downloads in this folder. It only reads file names and sizes."
        NSApp.activate()
        guard await panel.begin() == .OK, let url = panel.url else { return }
        use(url)
    }

    /// Keeps a folder the user granted (from the open panel).
    func use(_ url: URL) {
        do {
            defaults.set(try bookmarks.make(url), forKey: AppSettings.Key.downloadsBookmark)
            Self.logger.info("Watching \(url.lastPathComponent, privacy: .public)")
            set(url)
        } catch {
            Self.logger.error("Can't keep access to the folder: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func set(_ url: URL) {
        if let folder, folder != url { bookmarks.stopAccessing(folder) }
        folder = url
    }
}
