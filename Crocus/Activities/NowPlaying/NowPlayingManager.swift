import AppKit
import os

/// Shows what Spotify or the Music app is playing. Listens to the players'
/// own notifications (they carry the track) and only sends Apple Events for
/// what they leave out – Music's position, Spotify's cover – and for the
/// controls. Nothing is polled. Music's cover comes from the iTunes Search
/// API (`ITunesArtwork`).
///
/// Permission: never asked out of the blue – only from the onboarding's
/// explainer page or the menu ("Allow Spotify…"). Until then, and when
/// denied, only that player is off.
@MainActor
@Observable
final class NowPlayingManager {
    static let activityID = "nowPlaying"

    /// Last known state per player.
    private(set) var states: [MusicPlayer: NowPlayingState] = [:]
    private(set) var permissions: [MusicPlayer: PlayerPermission] = [:]
    private(set) var activity: NowPlayingActivity?

    @ObservationIgnored private let store: IslandStore
    @ObservationIgnored private let bridge: any PlayerBridge
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let loadData: @Sendable (URL) async -> Data?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var pending: [MusicPlayer: NowPlayingUpdate] = [:]
    /// Last cover per player, so it is back at once after a switch.
    @ObservationIgnored private var artwork: [MusicPlayer: (trackKey: String, image: NSImage)] = [:]
    /// iTunes Search results per Music track (`nil`: not in the store).
    @ObservationIgnored private var lookups: [String: URL?] = [:]
    @ObservationIgnored private var handling: Set<MusicPlayer> = []
    /// The cover being loaded; tests wait for it.
    @ObservationIgnored private(set) var artworkTask: Task<Void, Never>?
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "NowPlaying")

    init(
        store: IslandStore,
        bridge: any PlayerBridge = AppleScriptPlayerBridge(),
        now: @escaping () -> Date = Date.init,
        loadData: @escaping @Sendable (URL) async -> Data? = { url in try? await URLSession.shared.data(from: url).0 }
    ) {
        self.store = store
        self.bridge = bridge
        self.now = now
        self.loadData = loadData
    }

    func start() {
        let distributed = DistributedNotificationCenter.default()
        for player in MusicPlayer.allCases {
            observers.append(distributed.addObserver(forName: player.notificationName, object: nil, queue: .main) { [weak self] note in
                guard let update = note.userInfo.flatMap({ NowPlayingUpdate(player: player, userInfo: $0) }) else { return }
                MainActor.assumeIsolated {
                    guard let self else { return }
                    Task { await self.handle(update, from: player) }
                }
            })
        }
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                guard let bundleID, let player = MusicPlayer(bundleID: bundleID) else { return }
                self?.playerQuit(player)
            }
        })
    }

    // MARK: - Updates

    /// A notification from a player. Players often send several in a row;
    /// while one is being handled (e.g. the permission check), only the
    /// newest waiting one is kept – each carries the full state – and none
    /// is dropped.
    func handle(_ update: NowPlayingUpdate, from player: MusicPlayer) async {
        pending[player] = update
        guard !handling.contains(player) else { return }
        handling.insert(player)
        defer { handling.remove(player) }
        while let next = pending.removeValue(forKey: player) {
            await process(next, from: player)
        }
    }

    private func process(_ update: NowPlayingUpdate, from player: MusicPlayer) async {
        Self.logger.info("\(player.displayName, privacy: .public): \(update.playback.rawValue, privacy: .public) '\(update.title ?? "", privacy: .public)'")
        guard update.playback != .stopped else {
            states[player] = nil
            refresh()
            return
        }
        guard await isAllowed(player, asking: false) else { return }

        let time = now()
        let previousKey = states[player]?.trackKey
        if var state = states[player] {
            state.apply(update, now: time)
            states[player] = state
        } else {
            states[player] = NowPlayingState(player: player, update: update, now: time)
        }
        // Music doesn't send its position.
        if update.position == nil, let position = bridge.position(player) {
            states[player]?.setPosition(position, now: time)
        }
        refresh()

        if previousKey != update.trackKey {
            // In the background: the next notification shouldn't wait for it.
            artworkTask = Task { await loadArtwork(for: player, trackKey: update.trackKey) }
        }
    }

    /// Onboarding and menu: asks macOS (after the explainer). Starts the
    /// player in the background first if needed – macOS only asks about
    /// running apps.
    @discardableResult
    func requestPermission(_ player: MusicPlayer) async -> PlayerPermission {
        guard await bridge.launchInBackground(player) else { return .unavailable }
        let permission = await bridge.permission(player, askIfNeeded: true)
        permissions[player] = permission
        Self.logger.info("\(player.displayName, privacy: .public) permission asked: \(String(describing: permission), privacy: .public)")
        return permission
    }

    /// Without asking: `unavailable` while the player isn't running.
    func currentPermission(_ player: MusicPlayer) async -> PlayerPermission {
        if let known = permissions[player], known == .granted || known == .denied { return known }
        return await bridge.permission(player, askIfNeeded: false)
    }

    func isInstalled(_ player: MusicPlayer) -> Bool { bridge.isInstalled(player) }

    /// Settings: looks the permission up again (without asking) and keeps it.
    func refreshPermission(_ player: MusicPlayer) async {
        let permission = await currentPermission(player)
        if permission != .unavailable { permissions[player] = permission }
    }

    private func isAllowed(_ player: MusicPlayer, asking: Bool) async -> Bool {
        switch permissions[player] {
        case .granted: return true
        case .denied: return false
        case .notDetermined, .unavailable, nil: break
        }
        let permission = await bridge.permission(player, askIfNeeded: asking)
        permissions[player] = permission
        Self.logger.info("\(player.displayName, privacy: .public) permission: \(String(describing: permission), privacy: .public)")
        return permission == .granted
    }

    private func loadArtwork(for player: MusicPlayer, trackKey: String) async {
        guard let url = await artworkURL(for: player), let data = await loadData(url),
              let image = NSImage(data: data),
              states[player]?.trackKey == trackKey // still the same track?
        else { return }
        artwork[player] = (trackKey, image)
        showArtwork()
    }

    /// Spotify names its cover; for Music it is looked up in the iTunes
    /// Search API – once per track.
    private func artworkURL(for player: MusicPlayer) async -> URL? {
        switch player {
        case .spotify:
            return bridge.artworkURL(player)
        case .music:
            guard let state = states[player], let artist = state.artist else { return nil }
            if let cached = lookups[state.trackKey] { return cached }
            guard let search = ITunesArtwork.searchURL(title: state.title, artist: artist, country: ITunesArtwork.country),
                  let data = await loadData(search)
            else { return nil } // offline: try again next time
            let url = ITunesArtwork.artworkURL(in: data, title: state.title, artist: artist, album: state.album)
            lookups[state.trackKey] = url
            if url == nil { Self.logger.info("No cover found for '\(state.title, privacy: .public)'") }
            return url
        }
    }

    /// Puts the cached cover of the shown player into the island – also
    /// when switching back to a player whose track hasn't changed.
    private func showArtwork() {
        guard let activity, let cached = artwork[activity.state.player],
              cached.trackKey == activity.state.trackKey
        else { return }
        activity.setArtwork(cached.image, for: cached.trackKey)
    }

    private func playerQuit(_ player: MusicPlayer) {
        states[player] = nil
        artwork[player] = nil
        // Ask again (or re-check) next time it runs.
        if permissions[player] != .denied { permissions[player] = nil }
        refresh()
    }

    // MARK: - Island

    /// The player to show: the one that most recently started playing, or
    /// – if none plays – the one paused last (for 5 min).
    static func displayed(_ states: [MusicPlayer: NowPlayingState], now: Date) -> NowPlayingState? {
        let live = states.values.filter { !$0.isExpired(now: now) }
        if let playing = live.filter(\.isPlaying).max(by: { ($0.playingSince ?? .distantPast) < ($1.playingSince ?? .distantPast) }) {
            return playing
        }
        return live.max { $0.lastChange < $1.lastChange }
    }

    /// Updates the island and schedules the pause timeout.
    func refresh() {
        let time = now()
        states = states.filter { !$0.value.isExpired(now: time) }
        guard let shown = Self.displayed(states, now: time) else {
            if activity != nil {
                activity = nil
                store.remove(id: Self.activityID)
            }
            deadlineTask?.cancel()
            return
        }
        if let activity {
            if activity.state.player != shown.player {
                Self.logger.info("Showing \(shown.player.displayName, privacy: .public)")
            }
            activity.update(shown)
        } else {
            Self.logger.info("Showing \(shown.player.displayName, privacy: .public)")
            let activity = NowPlayingActivity(state: shown, startedAt: time)
            activity.onCommand = { [weak self] command in self?.send(command) }
            activity.onOpenPlayer = { [weak self] in self?.openPlayer() }
            self.activity = activity
            store.upsert(activity)
        }
        showArtwork()
        schedule(after: time)
    }

    private func schedule(after time: Date) {
        deadlineTask?.cancel()
        let next = states.values.filter { $0.playback == .paused }.map { $0.lastChange.addingTimeInterval(NowPlayingState.pausedTimeout) }.min()
        guard let next else { return }
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(next.timeIntervalSince(time), 0.05)))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    // MARK: - Controls

    func send(_ command: PlayerCommand) {
        guard let player = activity?.state.player, permissions[player] == .granted else { return }
        bridge.send(command, to: player)
        // Answer right away; the player's notification confirms it.
        if command == .playPause, var state = states[player] {
            let time = now()
            let position = state.position(now: time)
            state.apply(NowPlayingUpdate(
                title: state.title, artist: state.artist, album: state.album, duration: state.duration,
                position: position, playback: state.isPlaying ? .paused : .playing, trackKey: state.trackKey
            ), now: time)
            states[player] = state
            refresh()
        }
    }

    func openPlayer() {
        guard let player = activity?.state.player else { return }
        bridge.open(player)
        store.collapse()
    }

    /// Privacy & Security → Automation, to allow a denied player later.
    static let automationSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
}
