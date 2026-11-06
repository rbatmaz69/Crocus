import Foundation
import Testing
@testable import Crocus

@Suite struct PartialDownloadTests {
    @Test(arguments: [
        ("Xcode.xip.download", PartialDownload.Browser.safari, "Xcode.xip"),
        ("movie.mp4.crdownload", .chrome, "movie.mp4"),
        ("Unconfirmed 812345.crdownload", .chrome, "Unconfirmed 812345"),
        ("archive.zip.part", .firefox, "archive.zip"),
        ("Report.PDF.PART", .firefox, "Report.PDF"),
    ])
    func recognises(_ name: String, _ browser: PartialDownload.Browser, _ display: String) throws {
        let partial = try #require(PartialDownload(url: URL(fileURLWithPath: "/tmp/Downloads/\(name)")))
        #expect(partial.browser == browser)
        #expect(partial.displayName == display)
        #expect(partial.finalURL.path == "/tmp/Downloads/\(display)")
    }

    @Test(arguments: ["Xcode.xip", "notes.txt", ".part", "download"])
    func ignores(_ name: String) {
        #expect(PartialDownload(url: URL(fileURLWithPath: "/tmp/Downloads/\(name)")) == nil)
    }
}

@Suite struct DownloadsStateTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func shownAfterOneSecond() {
        var state = DownloadsState()
        state.update(id: "a", name: "a.zip", completedBytes: 10, totalBytes: 100, now: t0)
        #expect(state.visible(now: t0 + 0.9).isEmpty)
        #expect(state.nextDeadline(now: t0) == t0 + 1)
        #expect(state.visible(now: t0 + 1).map(\.id) == ["a"])
    }

    @Test func smallDownloadsNeverShow() {
        var state = DownloadsState()
        state.update(id: "a", name: "a.pdf", completedBytes: 10, totalBytes: 10, now: t0)
        state.finish(id: "a", now: t0 + 0.5)
        #expect(state.items.isEmpty)
    }

    @Test func finishedShowsCheckForThreeSeconds() {
        var state = DownloadsState()
        state.update(id: "a", name: "a.zip", completedBytes: 10, totalBytes: 100, now: t0)
        state.finish(id: "a", now: t0 + 20)
        let item = state.visible(now: t0 + 20).first
        #expect(item?.finishedAt == t0 + 20)
        #expect(item?.completedBytes == 100)
        #expect(state.nextDeadline(now: t0 + 20) == t0 + 23)
        state.prune(now: t0 + 22.9)
        #expect(!state.items.isEmpty)
        state.prune(now: t0 + 23)
        #expect(state.items.isEmpty)
    }

    @Test func cancelledShowsCrossForThreeSeconds() {
        var state = DownloadsState()
        state.update(id: "a", name: "a.zip", completedBytes: 10, totalBytes: 100, now: t0)
        state.cancel(id: "a", now: t0 + 5)
        let item = state.visible(now: t0 + 5).first
        #expect(item?.isCancelled == true)
        #expect(item?.completedBytes == 10)
        #expect(DownloadsFormat.sizeLine(item!) == "Cancelled")
        state.prune(now: t0 + 8)
        #expect(state.items.isEmpty)
    }

    @Test func cancelledBeforeShownNeverShows() {
        var state = DownloadsState()
        state.update(id: "a", name: "a.zip", completedBytes: 10, totalBytes: 100, now: t0)
        state.cancel(id: "a", now: t0 + 0.5)
        #expect(state.items.isEmpty)
    }

    @Test func stalledGoesQuietly() {
        var state = DownloadsState()
        state.update(id: "a", name: "a.zip", completedBytes: 10, totalBytes: 100, now: t0)
        state.remove(id: "a")
        #expect(state.items.isEmpty)
    }

    @Test func overallProgress() {
        var state = DownloadsState()
        state.update(id: "a", name: "a", completedBytes: 50, totalBytes: 100, now: t0)
        state.update(id: "b", name: "b", completedBytes: 250, totalBytes: 300, now: t0)
        #expect(state.overallFraction(now: t0 + 2) == 0.75)
        state.update(id: "c", name: "c", completedBytes: 5, totalBytes: nil, now: t0)
        #expect(state.overallFraction(now: t0 + 2) == nil) // a size is unknown → spinner
        #expect(state.visible(now: t0 + 2).map(\.id) == ["a", "b", "c"])
    }

    @Test func knownTotalIsKeptWhenAnUpdateHasNone() {
        var state = DownloadsState()
        state.update(id: "a", name: "a", completedBytes: 10, totalBytes: 100, now: t0)
        state.update(id: "a", name: "a", completedBytes: 20, totalBytes: nil, now: t0 + 1)
        #expect(state.items["a"]?.totalBytes == 100)
        #expect(state.items["a"]?.fraction == 0.2)
    }
}

@Suite struct DownloadsFormatTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func lines() {
        let running = DownloadsState.Item(id: "a", name: "Xcode.xip", completedBytes: 412_000_000, totalBytes: 1_200_000_000, firstSeen: t0)
        // Sizes follow the user's locale ("1.2 GB" / "1,2 GB"); the line's shape doesn't.
        #expect(DownloadsFormat.sizeLine(running) == "\(DownloadsFormat.size(412_000_000)) of \(DownloadsFormat.size(1_200_000_000))")
        let unknown = DownloadsState.Item(id: "b", name: "x", completedBytes: 12_300_000, totalBytes: nil, firstSeen: t0)
        #expect(DownloadsFormat.sizeLine(unknown) == DownloadsFormat.size(12_300_000))
        #expect(DownloadsFormat.percent(0.629) == "62 %")
        #expect(DownloadsFormat.count(1) == "1 file")
        #expect(DownloadsFormat.count(3) == "3 files")
    }

    @Test func accessibility() {
        let a = DownloadsState.Item(id: "a", name: "Xcode.xip", completedBytes: 1, totalBytes: 2, firstSeen: t0)
        #expect(DownloadsFormat.accessibilityLabel([a], overall: 0.5) == "Downloading Xcode.xip, 50 percent")
        var done = a
        done.finishedAt = t0
        #expect(DownloadsFormat.accessibilityLabel([done], overall: 1) == "Download finished, Xcode.xip")
        done.isCancelled = true
        #expect(DownloadsFormat.accessibilityLabel([done], overall: nil) == "Download cancelled, Xcode.xip")
    }
}

@MainActor
@Suite struct DownloadsFolderAccessTests {
    final class Calls: @unchecked Sendable { var started: [URL] = []; var stopped: [URL] = [] }

    let defaults: UserDefaults
    let calls = Calls()

    init() {
        let suite = "DownloadsFolderAccessTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    func access(stale: Bool = false, fails: Bool = false) -> DownloadsFolderAccess {
        let calls = calls
        return DownloadsFolderAccess(defaults: defaults, bookmarks: .init(
            make: { Data($0.path.utf8) },
            resolve: { data in
                if fails { throw CocoaError(.fileNoSuchFile) }
                return (URL(fileURLWithPath: String(decoding: data, as: UTF8.self)), stale)
            },
            startAccessing: { url in MainActor.assumeIsolated { calls.started.append(url) }; return true },
            stopAccessing: { url in MainActor.assumeIsolated { calls.stopped.append(url) } }
        ))
    }

    @Test func keptAcrossRelaunch() {
        access().use(URL(fileURLWithPath: "/Users/me/Downloads"))
        let relaunched = access()
        #expect(relaunched.restore()?.path == "/Users/me/Downloads")
        #expect(relaunched.folder?.path == "/Users/me/Downloads")
        #expect(calls.started.map(\.path) == ["/Users/me/Downloads"])
    }

    @Test func staleBookmarkIsRenewed() {
        defaults.set(Data("/Users/me/Moved".utf8), forKey: AppSettings.Key.downloadsBookmark)
        #expect(access(stale: true).restore() != nil)
        #expect(defaults.data(forKey: AppSettings.Key.downloadsBookmark) == Data("/Users/me/Moved".utf8))
    }

    @Test func goneFolderIsForgotten() {
        defaults.set(Data("/gone".utf8), forKey: AppSettings.Key.downloadsBookmark)
        #expect(access(fails: true).restore() == nil)
        #expect(defaults.data(forKey: AppSettings.Key.downloadsBookmark) == nil)
    }

    @Test func noBookmarkNoFolder() {
        #expect(access().restore() == nil)
    }
}

@MainActor
@Suite(.serialized) struct DownloadWatcherTests {
    let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "DownloadWatcherTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func write(_ name: String, bytes: Int) throws {
        try Data(count: bytes).write(to: folder.appending(path: name))
    }

    @Test func followsAPartialFileToTheEnd() throws {
        let watcher = DownloadWatcher()
        var changes: [DownloadChange] = []
        watcher.onChange = { changes += $0 }
        defer { watcher.stop(); try? FileManager.default.removeItem(at: folder) }

        try write("notes.txt", bytes: 10)
        try write("movie.mp4.crdownload", bytes: 1000)
        watcher.start(folder: folder)
        let id = folder.appending(path: "movie.mp4.crdownload").path
        #expect(changes == [.update(DownloadSample(id: id, name: "movie.mp4", completedBytes: 1000, totalBytes: nil))])

        // Finished: the partial file becomes the final one.
        changes = []
        try FileManager.default.moveItem(at: folder.appending(path: "movie.mp4.crdownload"), to: folder.appending(path: "movie.mp4"))
        watcher.scan()
        #expect(changes == [.finished(id: id)])
    }

    @Test func removedWithoutAFinalFileIsCancelled() throws {
        let watcher = DownloadWatcher()
        var changes: [DownloadChange] = []
        watcher.onChange = { changes += $0 }
        defer { watcher.stop(); try? FileManager.default.removeItem(at: folder) }

        try write("archive.zip.part", bytes: 500)
        watcher.start(folder: folder)
        changes = []
        try FileManager.default.removeItem(at: folder.appending(path: "archive.zip.part"))
        watcher.scan()
        #expect(changes == [.cancelled(id: folder.appending(path: "archive.zip.part").path)])
    }

    /// Firefox (and Zen): an empty placeholder with the real name, the data
    /// in a randomly named `.part`, renamed over the placeholder at the end.
    @Test func firefoxTemporaryNames() throws {
        let watcher = DownloadWatcher()
        var changes: [DownloadChange] = []
        watcher.onChange = { changes += $0 }
        defer { watcher.stop(); try? FileManager.default.removeItem(at: folder) }

        watcher.start(folder: folder)
        try write("googlechrome.dmg", bytes: 0)
        try write("Xy7k2Pq.dmg.part", bytes: 1000)
        watcher.scan()
        let id = folder.appending(path: "Xy7k2Pq.dmg.part").path
        #expect(changes == [.update(DownloadSample(id: id, name: "googlechrome.dmg", completedBytes: 1000, totalBytes: nil))])

        changes = []
        _ = try FileManager.default.replaceItemAt(folder.appending(path: "googlechrome.dmg"), withItemAt: folder.appending(path: "Xy7k2Pq.dmg.part"))
        watcher.scan()
        #expect(changes == [.finished(id: id, name: "googlechrome.dmg")])
    }

    @Test func firefoxCancelRemovesBoth() throws {
        let watcher = DownloadWatcher()
        var changes: [DownloadChange] = []
        watcher.onChange = { changes += $0 }
        defer { watcher.stop(); try? FileManager.default.removeItem(at: folder) }

        watcher.start(folder: folder)
        try write("googlechrome.dmg", bytes: 0)
        try write("Xy7k2Pq.dmg.part", bytes: 1000)
        watcher.scan()
        changes = []
        try FileManager.default.removeItem(at: folder.appending(path: "Xy7k2Pq.dmg.part"))
        try FileManager.default.removeItem(at: folder.appending(path: "googlechrome.dmg"))
        watcher.scan()
        #expect(changes == [.cancelled(id: folder.appending(path: "Xy7k2Pq.dmg.part").path)])
    }

    @Test func unrelatedFileDoesNotCountAsFinished() throws {
        let watcher = DownloadWatcher()
        var changes: [DownloadChange] = []
        watcher.onChange = { changes += $0 }
        defer { watcher.stop(); try? FileManager.default.removeItem(at: folder) }

        watcher.start(folder: folder)
        try write("Xy7k2Pq.dmg.part", bytes: 1000)
        watcher.scan()
        changes = []
        try FileManager.default.removeItem(at: folder.appending(path: "Xy7k2Pq.dmg.part"))
        try write("photo.jpg", bytes: 5000) // other type
        try write("tiny.dmg", bytes: 10)    // smaller than the download was
        watcher.scan()
        #expect(changes == [.cancelled(id: folder.appending(path: "Xy7k2Pq.dmg.part").path)])
    }

    @Test func stalledIsDroppedUntilItGrowsAgain() throws {
        let watcher = DownloadWatcher(staleAfter: 0.3)
        var changes: [DownloadChange] = []
        watcher.onChange = { changes += $0 }
        defer { watcher.stop(); try? FileManager.default.removeItem(at: folder) }

        let url = folder.appending(path: "big.zip.crdownload")
        try write("big.zip.crdownload", bytes: 1000)
        watcher.start(folder: folder)
        Thread.sleep(forTimeInterval: 0.4)
        changes = []
        watcher.scan()
        #expect(changes == [.stalled(id: url.path)])

        changes = []
        watcher.scan()
        #expect(changes.isEmpty) // still there, not growing: stays dropped

        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(count: 500))
        try handle.close()
        watcher.scan()
        #expect(changes == [.update(DownloadSample(id: url.path, name: "big.zip", completedBytes: 1500, totalBytes: nil))])
    }

    final class FakeProgress: ProgressLookup, @unchecked Sendable {
        var reading: PublishedProgress.Reading?
        func progress(for partial: PartialDownload, seen: Date) -> PublishedProgress.Reading? { reading }
    }

    /// Safari keeps the `.download` bundle when cancelled, but withdraws the
    /// progress it published.
    @Test func withdrawnProgressMeansCancelled() async throws {
        let progress = FakeProgress()
        let watcher = DownloadWatcher(withdrawnGrace: 0.2, progressLookup: progress)
        var changes: [DownloadChange] = []
        watcher.onChange = { changes += $0 }
        defer { watcher.stop(); try? FileManager.default.removeItem(at: folder) }

        let bundle = folder.appending(path: "Xcode.xip.download")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try Data(count: 400).write(to: bundle.appending(path: "Xcode.xip"))
        progress.reading = .init(completed: 400, total: 1000, isCancelled: false)
        watcher.start(folder: folder)
        #expect(changes == [.update(DownloadSample(id: bundle.path, name: "Xcode.xip", completedBytes: 400, totalBytes: 1000))])

        changes = []
        progress.reading = nil // withdrawn
        watcher.scan()
        #expect(!changes.contains(.cancelled(id: bundle.path))) // not yet: maybe it is just finishing
        try await Task.sleep(for: .milliseconds(250))
        watcher.scan()
        #expect(changes.contains(.cancelled(id: bundle.path)))

        // Still on disk and not growing: not shown again.
        changes = []
        watcher.scan()
        #expect(changes.isEmpty)
    }

    @Test func withdrawnThenGoneIsFinished() throws {
        let progress = FakeProgress()
        let watcher = DownloadWatcher(withdrawnGrace: 5, progressLookup: progress)
        var changes: [DownloadChange] = []
        watcher.onChange = { changes += $0 }
        defer { watcher.stop(); try? FileManager.default.removeItem(at: folder) }

        let bundle = folder.appending(path: "Xcode.xip.download")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try Data(count: 1000).write(to: bundle.appending(path: "Xcode.xip"))
        progress.reading = .init(completed: 1000, total: 1000, isCancelled: false)
        watcher.start(folder: folder)
        progress.reading = nil
        watcher.scan()
        changes = []
        try FileManager.default.moveItem(at: bundle.appending(path: "Xcode.xip"), to: folder.appending(path: "Xcode.xip"))
        try FileManager.default.removeItem(at: bundle)
        watcher.scan()
        #expect(changes == [.finished(id: bundle.path)])
    }

    @Test func cancelledProgressIsCancelledAtOnce() throws {
        let progress = FakeProgress()
        let watcher = DownloadWatcher(progressLookup: progress)
        var changes: [DownloadChange] = []
        watcher.onChange = { changes += $0 }
        defer { watcher.stop(); try? FileManager.default.removeItem(at: folder) }

        try write("movie.mp4.crdownload", bytes: 100)
        progress.reading = .init(completed: 100, total: 1000, isCancelled: false)
        watcher.start(folder: folder)
        changes = []
        progress.reading = .init(completed: 100, total: 1000, isCancelled: true)
        watcher.scan()
        #expect(changes == [.cancelled(id: folder.appending(path: "movie.mp4.crdownload").path)])
    }

    /// Old Safari bundles left from cancelled downloads must not be taken
    /// for the download whose progress just arrived without a file URL.
    @Test func progressWithoutURLDoesNotWakeOldFiles() throws {
        let old = folder.appending(path: "old.dmg.download")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try Data(count: 100).write(to: old.appending(path: "old.dmg"))
        let past = Date(timeIntervalSinceNow: -1200)
        try FileManager.default.setAttributes([.creationDate: past, .modificationDate: past], ofItemAtPath: old.path)

        let published = PublishedProgress()
        let progress = Progress(totalUnitCount: 1000)
        published.add(progress) // no file URL, published now
        let watcher = DownloadWatcher(progressLookup: published)
        var changes: [DownloadChange] = []
        watcher.onChange = { changes += $0 }
        defer { watcher.stop(); try? FileManager.default.removeItem(at: folder) }

        watcher.start(folder: folder)
        #expect(changes.isEmpty)
    }

    @Test func leftOverPartialFilesAreIgnored() throws {
        let watcher = DownloadWatcher()
        var changes: [DownloadChange] = []
        watcher.onChange = { changes += $0 }
        defer { watcher.stop(); try? FileManager.default.removeItem(at: folder) }

        let old = folder.appending(path: "old.dmg.crdownload")
        try Data(count: 100).write(to: old)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -3600)], ofItemAtPath: old.path)
        watcher.start(folder: folder)
        #expect(changes.isEmpty)
    }

    @Test func safariBundleSizeIsTheSumOfItsFiles() throws {
        let bundle = folder.appending(path: "Xcode.xip.download")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try Data(count: 700).write(to: bundle.appending(path: "Xcode.xip"))
        try Data(count: 300).write(to: bundle.appending(path: "Info.plist"))
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(DownloadWatcher.size(of: bundle) == 1000)
    }
}

@MainActor
final class FakeDownloadWatcher: DownloadWatching {
    var onChange: (([DownloadChange]) -> Void)?
    var startedWith: [URL] = []
    func start(folder: URL) { startedWith.append(folder) }
    func stop() {}
}

@MainActor
@Suite struct DownloadsManagerTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_000_000) }

    let clock = Clock()
    let watcher = FakeDownloadWatcher()
    let store: IslandStore
    let defaults: UserDefaults

    init() {
        let suite = "DownloadsManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        store = IslandStore(defaults: defaults)
    }

    func manager() -> DownloadsManager {
        let clock = clock
        let access = DownloadsFolderAccess(defaults: defaults, bookmarks: .init(
            make: { Data($0.path.utf8) },
            resolve: { (URL(fileURLWithPath: String(decoding: $0, as: UTF8.self)), false) },
            startAccessing: { _ in true }, stopAccessing: { _ in }
        ))
        let manager = DownloadsManager(store: store, access: access, watcher: watcher, now: { clock.now })
        manager.start()
        return manager
    }

    func sample(_ id: String, _ done: Int64, of total: Int64?) -> DownloadChange {
        .update(DownloadSample(id: id, name: "\(id).zip", completedBytes: done, totalBytes: total))
    }

    @Test func startsWatchingTheBookmarkedFolder() {
        defaults.set(Data("/Users/me/Downloads".utf8), forKey: AppSettings.Key.downloadsBookmark)
        _ = manager()
        #expect(watcher.startedWith.map(\.path) == ["/Users/me/Downloads"])
    }

    @Test func noFolderNoWatching() {
        _ = manager()
        #expect(watcher.startedWith.isEmpty)
    }

    @Test func downloadLifecycle() {
        let manager = manager()
        manager.apply([sample("a", 10, of: 100)])
        #expect(manager.activity == nil) // < 1 s

        clock.now += 1
        manager.apply([sample("a", 50, of: 100)])
        #expect(store.primaryActivity?.kind == .download)
        #expect(manager.activity?.overall == 0.5)

        clock.now += 10
        manager.apply([.finished(id: "a")])
        #expect(manager.activity?.allEnded == true)

        clock.now += 3
        manager.refresh()
        #expect(manager.activity == nil)
        #expect(store.presentation == .idle)
    }

    @Test func cancelledShowsCrossThenDisappears() {
        let manager = manager()
        manager.apply([sample("a", 10, of: 100)])
        clock.now += 2
        manager.refresh()
        manager.apply([.cancelled(id: "a")])
        #expect(manager.activity?.allEnded == true)
        #expect(manager.activity?.endResult == .failure)
        clock.now += 3
        manager.refresh()
        #expect(manager.activity == nil)
    }

    @Test func stalledDisappearsAtOnce() {
        let manager = manager()
        manager.apply([sample("a", 10, of: 100)])
        clock.now += 2
        manager.refresh()
        manager.apply([.stalled(id: "a")])
        #expect(manager.activity == nil)
    }

    @Test func mixedEndingsShowCheck() {
        let manager = manager()
        manager.apply([sample("a", 10, of: 100), sample("b", 10, of: 100)])
        clock.now += 2
        manager.apply([.finished(id: "a"), .cancelled(id: "b")])
        #expect(manager.activity?.endResult == .success)
    }
}

@Suite struct PublishedProgressTests {
    let partial = PartialDownload(url: URL(fileURLWithPath: "/Users/me/Downloads/Xcode.xip.download"))!

    func progress(url: URL?, done: Int64 = 400) -> Progress {
        let progress = Progress(totalUnitCount: 1000)
        progress.fileURL = url
        progress.completedUnitCount = done
        return progress
    }

    @Test func matchesByPathInsideTheBundle() {
        let published = PublishedProgress()
        published.add(progress(url: URL(fileURLWithPath: "/Users/me/Downloads/Other.zip.download")))
        published.add(progress(url: URL(fileURLWithPath: "/Users/me/Downloads/Xcode.xip.download/Xcode.xip"), done: 700))
        #expect(published.progress(for: partial, seen: .distantPast)?.completed == 700)
    }

    @Test func withoutURLMatchesByTiming() {
        let published = PublishedProgress()
        let progress = progress(url: nil)
        published.add(progress)
        #expect(published.progress(for: partial, seen: Date())?.completed == 400)
        #expect(published.progress(for: partial, seen: Date(timeIntervalSinceNow: -60)) == nil) // too far apart

        published.remove(progress)
        #expect(published.progress(for: partial, seen: Date()) == nil) // withdrawn
    }

    @Test func withoutURLAmbiguousMatchesNothing() {
        let published = PublishedProgress()
        published.add(progress(url: nil))
        published.add(progress(url: nil))
        #expect(published.progress(for: partial, seen: Date()) == nil)
    }
}
