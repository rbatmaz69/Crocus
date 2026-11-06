import Foundation
import os

/// Shows running downloads from the folder the user picked: one activity
/// for all of them, priority 5.
@MainActor
@Observable
final class DownloadsManager {
    static let activityID = "downloads"

    let access: DownloadsFolderAccess
    private(set) var state = DownloadsState()
    private(set) var activity: DownloadsActivity?

    @ObservationIgnored private let store: IslandStore
    @ObservationIgnored private let watcher: any DownloadWatching
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?

    init(
        store: IslandStore,
        access: DownloadsFolderAccess = DownloadsFolderAccess(),
        watcher: any DownloadWatching = DownloadWatcher(),
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.access = access
        self.watcher = watcher
        self.now = now
    }

    func start() {
        watcher.onChange = { [weak self] changes in self?.apply(changes) }
        if let folder = access.restore() { watcher.start(folder: folder) }
    }

    /// Menu bar: "Choose Downloads Folder…".
    func chooseFolder() async {
        await access.choose()
        if let folder = access.folder { watcher.start(folder: folder) }
    }

    func apply(_ changes: [DownloadChange]) {
        let time = now()
        for change in changes {
            switch change {
            case .update(let sample):
                state.update(id: sample.id, name: sample.name, completedBytes: sample.completedBytes, totalBytes: sample.totalBytes, now: time)
            case .finished(let id, let name):
                state.finish(id: id, name: name, now: time)
            case .cancelled(let id):
                state.cancel(id: id, now: time)
            case .stalled(let id):
                state.remove(id: id)
            }
        }
        refresh()
    }

    func refresh() {
        let time = now()
        state.prune(now: time)
        let visible = state.visible(now: time)
        if visible.isEmpty {
            if activity != nil {
                activity = nil
                store.remove(id: Self.activityID)
            }
        } else if let activity {
            activity.update(items: visible, overall: state.overallFraction(now: time))
        } else {
            let activity = DownloadsActivity(items: visible, overall: state.overallFraction(now: time), startedAt: time)
            self.activity = activity
            store.upsert(activity)
        }

        deadlineTask?.cancel()
        guard let deadline = state.nextDeadline(now: time) else { return }
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(deadline.timeIntervalSince(time), 0.05)), tolerance: .milliseconds(10))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}
