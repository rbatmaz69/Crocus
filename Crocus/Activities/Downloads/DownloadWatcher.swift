import Foundation
import os

/// One reading of a running download.
struct DownloadSample: Equatable, Sendable {
    let id: String
    let name: String
    let completedBytes: Int64
    let totalBytes: Int64?
}

enum DownloadChange: Equatable, Sendable {
    case update(DownloadSample)
    /// `name`: the finished file's name when it differs from the partial
    /// file's (Firefox writes to a random temporary name).
    case finished(id: String, name: String? = nil)
    /// Cancelled in the browser: shown with ✕.
    case cancelled(id: String)
    /// Not growing for a while (paused, left over): hidden quietly.
    case stalled(id: String)
}

/// Watches a folder for browser downloads:
/// - new, renamed and removed files via a file system event on the folder
/// - bytes from the progress browsers publish (`NSProgress`, as Finder
///   shows it), else from the growing file size – read once per second
///   only while a download runs
/// - a partial file that disappears: finished if its final file is there –
///   or, for browsers with temporary names (Firefox), a file that just
///   appeared or changed and is at least as big – cancelled otherwise
/// - cancelled while the partial file stays (Safari keeps it to resume):
///   the browser withdraws or cancels its published progress
/// - partial files that haven't grown for 60 s (left over, paused) are
///   ignored
/// - a dropped partial file only comes back if it grows again (resumed)
/// Only names and sizes are read.
@MainActor
protocol DownloadWatching: AnyObject {
    var onChange: (([DownloadChange]) -> Void)? { get set }
    func start(folder: URL)
    func stop()
}

@MainActor
final class DownloadWatcher: DownloadWatching {
    var onChange: (([DownloadChange]) -> Void)?

    static let pollInterval: Duration = .seconds(1)
    /// A Firefox placeholder must be at most this old.
    static let placeholderAge: TimeInterval = 5

    /// Partial files not growing for this long are dropped.
    let staleAfter: TimeInterval
    /// Progress withdrawn but the file still there this long: cancelled.
    /// (On success the file goes right after – then it is "finished".)
    let withdrawnGrace: TimeInterval

    /// Where published progress is looked up; a fake in tests (progress
    /// published in the same process doesn't reach the subscriber).
    private let progressLookup: any ProgressLookup

    init(staleAfter: TimeInterval = 60, withdrawnGrace: TimeInterval = 2, progressLookup: (any ProgressLookup)? = nil) {
        self.staleAfter = staleAfter
        self.withdrawnGrace = withdrawnGrace
        self.progressLookup = progressLookup ?? published
    }

    private struct Tracked {
        let partial: PartialDownload
        /// The name to show; Firefox's empty placeholder file has the real
        /// one when the partial file's name is random.
        var name: String
        let seen: Date
        var lastSize: Int64
        var lastGrowth: Date
        /// The browser published progress for it at some point.
        var hadProgress = false
        /// When the browser withdrew its progress while the file stayed.
        var withdrawnAt: Date?
    }

    /// Other files in the folder at the last scan: size and modification.
    private struct FileInfo: Equatable {
        let size: Int64
        let modified: Date
    }

    private var folder: URL?
    private var folderSource: DispatchSourceFileSystemObject?
    private var subscriber: Any?
    private let published = PublishedProgress()
    private var tracked: [String: Tracked] = [:]
    private var files: [String: FileInfo] = [:]
    /// Partial files dropped while still there (cancelled, stalled), with
    /// their size then; back only once they grow.
    private var ignored: [String: Int64] = [:]
    private var pollTask: Task<Void, Never>?

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Downloads")

    func start(folder: URL) {
        stop()
        self.folder = folder
        let descriptor = open(folder.path, O_EVTONLY)
        if descriptor >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
            source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.scan() } }
            source.setCancelHandler { close(descriptor) }
            source.resume()
            folderSource = source
        } else {
            Self.logger.error("Can't watch \(folder.lastPathComponent, privacy: .public)")
        }
        let published = published
        subscriber = Progress.addSubscriber(forFileURL: folder) { progress in
            published.add(progress)
            return { published.remove(progress) }
        }
        scan()
    }

    func stop() {
        folderSource?.cancel()
        folderSource = nil
        if let subscriber { Progress.removeSubscriber(subscriber) }
        subscriber = nil
        pollTask?.cancel()
        pollTask = nil
        tracked = [:]
        ignored = [:]
    }

    /// Reads the folder: new partial files, and ones that are gone. Runs on
    /// every folder change (internal for tests).
    func scan() {
        guard let folder else { return }
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [])) ?? []
        let partials = Dictionary(urls.compactMap(PartialDownload.init).map { ($0.url.path, $0) }, uniquingKeysWith: { a, _ in a })
        let now = Date()
        var current: [String: FileInfo] = [:]
        for url in urls where PartialDownload(url: url) == nil {
            let values = try? url.resourceValues(forKeys: keys)
            current[url.path] = FileInfo(size: Int64(values?.fileSize ?? 0), modified: values?.contentModificationDate ?? .distantPast)
        }
        // Files that appeared or changed since the last scan.
        let fresh = current.filter { files[$0.key] != $0.value }
        defer { files = current }
        var changes: [DownloadChange] = []

        for (id, entry) in tracked where partials[id] == nil {
            tracked[id] = nil
            if FileManager.default.fileExists(atPath: entry.partial.finalURL.path) {
                changes.append(.finished(id: id))
            } else if let finished = Self.finishedFile(for: entry.partial, lastSize: entry.lastSize, among: fresh) {
                changes.append(.finished(id: id, name: URL(fileURLWithPath: finished).lastPathComponent))
            } else {
                changes.append(.cancelled(id: id))
                Self.logger.info("\(entry.partial.browser.rawValue, privacy: .public) download cancelled")
                continue
            }
            Self.logger.info("\(entry.partial.browser.rawValue, privacy: .public) download finished")
        }
        ignored = ignored.filter { partials[$0.key] != nil }
        for (id, partial) in partials where tracked[id] == nil {
            let dates = try? partial.url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
            let modified = dates?.contentModificationDate ?? now
            // When the file was created – not when Crocus saw it: progress
            // without a file URL must not match files lying around for long.
            let created = dates?.creationDate ?? now
            let size = Self.size(of: partial.url)
            if let size0 = ignored[id] {
                guard size > size0 else { continue } // still cancelled / stalled
                ignored[id] = nil // resumed
            }
            guard now.timeIntervalSince(modified) < staleAfter || progressLookup.progress(for: partial, seen: created) != nil else { continue }
            let name = Self.placeholder(for: partial, among: current, now: now) ?? partial.displayName
            tracked[id] = Tracked(partial: partial, name: name, seen: created, lastSize: size, lastGrowth: now)
            Self.logger.info("\(partial.browser.rawValue, privacy: .public) download started")
        }
        changes += samples(now: now)
        if !changes.isEmpty { onChange?(changes) }
        updatePolling()
    }

    /// For a partial file with a temporary name: the file that just
    /// appeared or changed, with the same extension, at least as big as
    /// the download was.
    private static func finishedFile(for partial: PartialDownload, lastSize: Int64, among fresh: [String: FileInfo]) -> String? {
        let ext = partial.finalURL.pathExtension.lowercased()
        return fresh
            .filter { $0.value.size >= lastSize && $0.value.size > 0 && URL(fileURLWithPath: $0.key).pathExtension.lowercased() == ext }
            .max { $0.value.modified < $1.value.modified }?.key
    }

    /// Firefox creates an empty file with the real name next to a partial
    /// file with a random one ("name.hj-Pdb19.dmg.part"). Not needed for
    /// the classic "name.ext.part".
    private static func placeholder(for partial: PartialDownload, among files: [String: FileInfo], now: Date) -> String? {
        guard partial.browser == .firefox, files[partial.finalURL.path] == nil else { return nil }
        let ext = partial.finalURL.pathExtension.lowercased()
        let empty = files.filter {
            $0.value.size == 0 && now.timeIntervalSince($0.value.modified) < placeholderAge
                && URL(fileURLWithPath: $0.key).pathExtension.lowercased() == ext
        }
        // The newest one: several downloads may start close together.
        return empty.max { $0.value.modified < $1.value.modified }.map { URL(fileURLWithPath: $0.key).lastPathComponent }
    }

    /// Current bytes of every running download; drops cancelled and
    /// stalled ones that are still on disk.
    private func samples(now: Date) -> [DownloadChange] {
        var changes: [DownloadChange] = []
        for (id, entry) in tracked {
            let size = Self.size(of: entry.partial.url)
            let progress = progressLookup.progress(for: entry.partial, seen: entry.seen)
            if progress != nil { tracked[id]?.hadProgress = true }
            if size > entry.lastSize { tracked[id]?.lastSize = size; tracked[id]?.lastGrowth = now }

            if progress != nil {
                tracked[id]?.withdrawnAt = nil
            } else if entry.hadProgress, entry.withdrawnAt == nil {
                tracked[id]?.withdrawnAt = now
            }
            let withdrawn = (tracked[id]?.withdrawnAt).map { now.timeIntervalSince($0) >= withdrawnGrace } ?? false
            let stalled = progress == nil && now.timeIntervalSince(tracked[id]?.lastGrowth ?? now) >= staleAfter
            if progress?.isCancelled == true || withdrawn || stalled {
                tracked[id] = nil
                ignored[id] = size
                let cancelled = progress?.isCancelled == true || withdrawn
                changes.append(cancelled ? .cancelled(id: id) : .stalled(id: id))
                let reason = cancelled ? "cancelled" : "stalled"
                Self.logger.info("\(entry.partial.browser.rawValue, privacy: .public) download \(reason, privacy: .public), file kept")
                continue
            }
            changes.append(.update(DownloadSample(
                id: id,
                name: entry.name,
                completedBytes: progress.map { max($0.completed, 0) } ?? size,
                totalBytes: progress.flatMap { $0.total > 0 ? $0.total : nil }
            )))
        }
        return changes
    }

    private func updatePolling() {
        guard !tracked.isEmpty else {
            pollTask?.cancel()
            pollTask = nil
            return
        }
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard let self, !Task.isCancelled else { return }
                let changes = self.samples(now: Date())
                if !changes.isEmpty { self.onChange?(changes) }
                if self.tracked.isEmpty { self.pollTask = nil; return }
            }
        }
    }

    /// File size, or the sum of a Safari `.download` bundle's contents.
    static func size(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        guard values.isDirectory == true else { return Int64(values.fileSize ?? 0) }
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys))
        var total: Int64 = 0
        while let file = enumerator?.nextObject() as? URL {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}

/// Looks up the progress a browser published for a partial file.
protocol ProgressLookup: AnyObject, Sendable {
    /// `seen`: when the partial file was created – to match progress that
    /// arrives without a file URL (Safari, sometimes) by its timing.
    func progress(for partial: PartialDownload, seen: Date) -> PublishedProgress.Reading?
}

/// Progress objects browsers publish for files in the folder. Called from
/// any thread; `Progress` properties are thread-safe.
final class PublishedProgress: ProgressLookup, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [ObjectIdentifier: (progress: Progress, published: Date)] = [:]
    /// Progress without a file URL matches a download that appeared this
    /// close to it – if it is the only such one.
    static let timingWindow: TimeInterval = 3
    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Downloads")

    func add(_ progress: Progress) {
        lock.withLock { items[ObjectIdentifier(progress)] = (progress, Date()) }
        Self.logger.info("Progress published: \(progress.fileURL?.lastPathComponent ?? "no file URL", privacy: .public), total \(progress.totalUnitCount, privacy: .public)")
    }

    func remove(_ progress: Progress) {
        lock.withLock { items[ObjectIdentifier(progress)] = nil }
        Self.logger.info("Progress withdrawn: \(progress.fileURL?.lastPathComponent ?? "no file URL", privacy: .public)")
    }

    struct Reading: Equatable, Sendable {
        let completed: Int64
        let total: Int64
        let isCancelled: Bool
    }

    /// The progress for a partial file: published for the partial file
    /// itself, a file inside Safari's bundle, or the final file – or, without
    /// a file URL, the only one published around the time it appeared.
    func progress(for partial: PartialDownload, seen: Date) -> Reading? {
        let paths = (partial.url.path, partial.finalURL.path)
        return lock.withLock {
            let values = items.values
            let byPath = values.first { item in
                guard let path = item.progress.fileURL?.path else { return false }
                return path == paths.0 || path == paths.1 || path.hasPrefix(paths.0 + "/")
            }
            let byTime = values.filter {
                $0.progress.fileURL == nil && abs($0.published.timeIntervalSince(seen)) < Self.timingWindow
            }
            let match = byPath ?? (byTime.count == 1 ? byTime.first : nil)
            return match.map { Reading(completed: $0.progress.completedUnitCount, total: $0.progress.totalUnitCount, isCancelled: $0.progress.isCancelled) }
        }
    }
}
