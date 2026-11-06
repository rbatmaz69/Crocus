import Foundation

/// A file a browser is still writing, recognised by its name:
/// Safari `name.download` (a bundle), Chrome `name.crdownload`,
/// Firefox `name.part`.
struct PartialDownload: Equatable, Sendable {
    enum Browser: String, Sendable {
        case safari, chrome, firefox
    }

    let url: URL
    let browser: Browser

    init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "download": browser = .safari
        case "crdownload": browser = .chrome
        case "part": browser = .firefox
        default: return nil
        }
        guard !url.deletingPathExtension().lastPathComponent.isEmpty else { return nil }
        self.url = url
    }

    /// Where the finished file will be: the name without the extension.
    var finalURL: URL { url.deletingPathExtension() }

    /// Shown in the island: the finished name ("Xcode.xip"). Chrome starts
    /// with "Unconfirmed 123.crdownload" until it knows the name.
    var displayName: String { finalURL.lastPathComponent }
}

/// Running and just ended downloads, as a pure value.
/// - shown after 1 s, so small files don't flash the island
/// - finished: ✓ for 3 s; cancelled: ✕ for 3 s; then gone
/// - stalled (paused, left over): gone quietly
struct DownloadsState: Equatable, Sendable {
    struct Item: Equatable, Sendable {
        let id: String
        var name: String
        var completedBytes: Int64
        /// `nil` when unknown (no progress published) – spinner.
        var totalBytes: Int64?
        let firstSeen: Date
        /// When it finished or was cancelled.
        var finishedAt: Date?
        var isCancelled = false

        var fraction: Double? {
            guard let totalBytes, totalBytes > 0 else { return finishedAt != nil && !isCancelled ? 1 : nil }
            return min(Double(completedBytes) / Double(totalBytes), 1)
        }
    }

    static let showAfter: TimeInterval = 1
    static let finishedDuration: TimeInterval = 3

    private(set) var items: [String: Item] = [:]

    mutating func update(id: String, name: String, completedBytes: Int64, totalBytes: Int64?, now: Date) {
        if var item = items[id] {
            item.name = name
            item.completedBytes = max(completedBytes, 0)
            item.totalBytes = totalBytes ?? item.totalBytes
            items[id] = item
        } else {
            items[id] = Item(id: id, name: name, completedBytes: max(completedBytes, 0), totalBytes: totalBytes, firstSeen: now)
        }
    }

    mutating func finish(id: String, name: String? = nil, now: Date) {
        guard var item = items[id], item.finishedAt == nil else { return }
        if let name { item.name = name }
        if now.timeIntervalSince(item.firstSeen) < Self.showAfter {
            items[id] = nil // was never shown
            return
        }
        item.finishedAt = now
        if let total = item.totalBytes { item.completedBytes = total }
        items[id] = item
    }

    /// Cancelled in the browser: ✕ for 3 s (gone at once if never shown).
    mutating func cancel(id: String, now: Date) {
        guard var item = items[id], item.finishedAt == nil else { return }
        if now.timeIntervalSince(item.firstSeen) < Self.showAfter {
            items[id] = nil
            return
        }
        item.finishedAt = now
        item.isCancelled = true
        items[id] = item
    }

    /// Stalled: gone without a symbol.
    mutating func remove(id: String) {
        items[id] = nil
    }

    mutating func prune(now: Date) {
        items = items.filter { _, item in
            guard let finished = item.finishedAt else { return true }
            return now.timeIntervalSince(finished) < Self.finishedDuration
        }
    }

    /// Downloads in the island, oldest first.
    func visible(now: Date) -> [Item] {
        items.values
            .filter { $0.finishedAt != nil || now.timeIntervalSince($0.firstSeen) >= Self.showAfter }
            .sorted { ($0.firstSeen, $0.id) < ($1.firstSeen, $1.id) }
    }

    func running(now: Date) -> [Item] { visible(now: now).filter { $0.finishedAt == nil } }

    /// Overall progress of the running downloads; `nil` if any size is
    /// unknown.
    func overallFraction(now: Date) -> Double? {
        let running = running(now: now)
        guard !running.isEmpty else { return visible(now: now).isEmpty ? nil : 1 }
        guard running.allSatisfy({ ($0.totalBytes ?? 0) > 0 }) else { return nil }
        let total = running.reduce(Int64(0)) { $0 + ($1.totalBytes ?? 0) }
        let done = running.reduce(Int64(0)) { $0 + min($1.completedBytes, $1.totalBytes ?? 0) }
        return Double(done) / Double(total)
    }

    /// When something changes without new data: a download reaching 1 s,
    /// or a ✓ ending.
    func nextDeadline(now: Date) -> Date? {
        items.values.compactMap { item -> Date? in
            if let finished = item.finishedAt { return finished.addingTimeInterval(Self.finishedDuration) }
            let shows = item.firstSeen.addingTimeInterval(Self.showAfter)
            return shows > now ? shows : nil
        }.min()
    }
}

/// Texts for the downloads views.
enum DownloadsFormat {
    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// "412 MB of 1.2 GB", "12.3 MB" (size unknown), "1.2 GB" (done),
    /// "Cancelled".
    static func sizeLine(_ item: DownloadsState.Item) -> String {
        if item.isCancelled { return "Cancelled" }
        if item.finishedAt != nil { return size(item.totalBytes ?? item.completedBytes) }
        guard let total = item.totalBytes, total > 0 else { return size(item.completedBytes) }
        return "\(size(item.completedBytes)) of \(size(total))"
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded(.down))) %"
    }

    /// "1 file", "3 files".
    static func count(_ count: Int) -> String {
        "\(count) file\(count == 1 ? "" : "s")"
    }

    static func accessibilityLabel(_ items: [DownloadsState.Item], overall: Double?) -> String {
        let running = items.filter { $0.finishedAt == nil }
        if running.isEmpty {
            if items.count == 1 { return "Download \(items[0].isCancelled ? "cancelled" : "finished"), \(items[0].name)" }
            return items.allSatisfy(\.isCancelled) ? "Downloads cancelled" : "Downloads finished"
        }
        var label = running.count == 1 ? "Downloading \(running[0].name)" : "Downloading \(running.count) files"
        if let overall { label += ", \(Int((overall * 100).rounded(.down))) percent" }
        return label
    }
}
