import AppKit
import Foundation
import Testing
@testable import Crocus

/// Real `userInfo` captured from Spotify and Music during the #14 spike.
enum NowPlayingSamples {
    static func spotify(state: String = "Playing", position: Double = 5.141, trackID: String = "spotify:track:4bhhJh6x5pzN19bwpRCeZG") -> [AnyHashable: Any] {
        [
            "Album Artist": "5l33p", "Album": "we shine together", "Artist": "5l33p", "Disc Number": 1,
            "Duration": 107238, "Has Artwork": 1, "Name": "we shine together", "Play Count": 0,
            "Playback Position": position, "Player State": state, "Popularity": 41,
            "Track ID": trackID, "Track Number": 1,
        ]
    }

    static func music(state: String = "Playing", name: String = "Rattle The Cage (feat. John 5)") -> [AnyHashable: Any] {
        ["Album": "Everything Under The Sun", "Artist": "Nickelback", "Name": name, "Player State": state, "Total Time": 89976]
    }
}

@Suite struct ITunesArtworkTests {
    /// Shaped like the real answer for "Nickelback Rattle The Cage".
    static let response = Data("""
    {"resultCount": 3, "results": [
      {"artistName": "Nickelback", "trackName": "Rattle The Cage (feat. John 5)", "collectionName": "Everything Under The Sun (Deluxe)",
       "artworkUrl100": "https://is1-ssl.mzstatic.com/image/thumb/deluxe/100x100bb.jpg"},
      {"artistName": "The Rods", "trackName": "Rattle The Cage", "collectionName": "Rattle The Cage",
       "artworkUrl100": "https://is1-ssl.mzstatic.com/image/thumb/rods/100x100bb.jpg"},
      {"artistName": "Nickelback", "trackName": "Rattle The Cage (feat. John 5)", "collectionName": "Everything Under The Sun",
       "artworkUrl100": "https://is1-ssl.mzstatic.com/image/thumb/album/100x100bb.jpg"}
    ]}
    """.utf8)

    @Test func exactMatchFromTheSameAlbumInLargeSize() {
        let url = ITunesArtwork.artworkURL(in: Self.response, title: "Rattle The Cage (feat. John 5)", artist: "Nickelback", album: "Everything Under The Sun")
        #expect(url?.absoluteString == "https://is1-ssl.mzstatic.com/image/thumb/album/600x600bb.jpg")
    }

    @Test func otherAlbumWhenTheAlbumDiffers() {
        let url = ITunesArtwork.artworkURL(in: Self.response, title: "rattle the cage (feat. john 5)", artist: "NICKELBACK", album: "Live")
        #expect(url?.absoluteString == "https://is1-ssl.mzstatic.com/image/thumb/deluxe/600x600bb.jpg")
    }

    @Test func noFuzzyMatches() {
        #expect(ITunesArtwork.artworkURL(in: Self.response, title: "Rattle The Cage", artist: "Nickelback", album: nil) == nil)
        #expect(ITunesArtwork.artworkURL(in: Self.response, title: "Unknown", artist: "Someone", album: nil) == nil)
        #expect(ITunesArtwork.artworkURL(in: Data("garbage".utf8), title: "a", artist: "b", album: nil) == nil)
    }

    @Test func searchURL() throws {
        let url = try #require(ITunesArtwork.searchURL(title: "Rattle The Cage", artist: "Nickelback", country: "DE"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(url.host() == "itunes.apple.com")
        #expect(items.contains(URLQueryItem(name: "term", value: "Nickelback Rattle The Cage")))
        #expect(items.contains(URLQueryItem(name: "entity", value: "song")))
        #expect(items.contains(URLQueryItem(name: "country", value: "DE")))
    }
}

@Suite struct NowPlayingUpdateTests {
    @Test func parsesSpotify() throws {
        let update = try #require(NowPlayingUpdate(player: .spotify, userInfo: NowPlayingSamples.spotify()))
        #expect(update.title == "we shine together")
        #expect(update.artist == "5l33p")
        #expect(update.duration == 107.238)
        #expect(update.position == 5.141)
        #expect(update.playback == .playing)
        #expect(update.trackKey == "spotify:track:4bhhJh6x5pzN19bwpRCeZG")
    }

    @Test func parsesMusicWithoutPosition() throws {
        let update = try #require(NowPlayingUpdate(player: .music, userInfo: NowPlayingSamples.music(state: "Paused")))
        #expect(update.title == "Rattle The Cage (feat. John 5)")
        #expect(update.duration == 89.976)
        #expect(update.position == nil)
        #expect(update.playback == .paused)
    }

    @Test func stoppedNeedsNoTrack() throws {
        let update = try #require(NowPlayingUpdate(player: .spotify, userInfo: ["Player State": "Stopped"]))
        #expect(update.playback == .stopped)
    }

    @Test func rejectsGarbage() {
        #expect(NowPlayingUpdate(player: .music, userInfo: [:]) == nil)
        #expect(NowPlayingUpdate(player: .music, userInfo: ["Player State": "Exploding", "Name": "x"]) == nil)
        #expect(NowPlayingUpdate(player: .music, userInfo: ["Player State": "Playing"]) == nil) // no title
    }
}

@Suite struct NowPlayingStateTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func state(_ playback: NowPlayingState.Playback = .playing, position: Double? = 10) -> NowPlayingState {
        NowPlayingState(player: .spotify, update: NowPlayingUpdate(title: "A", duration: 100, position: position, playback: playback, trackKey: "a"), now: t0)
    }

    @Test func positionMovesOnWhilePlaying() {
        let playing = state()
        #expect(playing.position(now: t0 + 5) == 15)
        #expect(playing.remaining(now: t0 + 5) == 85)
        #expect(playing.progress(now: t0 + 40) == 0.5)
        #expect(playing.position(now: t0 + 500) == 100) // clamped

        let paused = state(.paused)
        #expect(paused.position(now: t0 + 5) == 10)
    }

    @Test func newTrackStartsAtZeroWithoutPosition() {
        var current = state()
        current.apply(NowPlayingUpdate(title: "B", playback: .playing, trackKey: "b"), now: t0 + 30)
        #expect(current.title == "B")
        #expect(current.position(now: t0 + 30) == 0)
        #expect(current.duration == nil)
    }

    @Test func sameTrackKeepsMovingWithoutPosition() {
        var current = state()
        current.apply(NowPlayingUpdate(title: "A", playback: .paused, trackKey: "a"), now: t0 + 30)
        #expect(current.position(now: t0 + 100) == 40)
        #expect(current.duration == 100)
    }

    @Test func playingSinceAndExpiry() {
        var current = state(.paused)
        #expect(current.playingSince == nil)
        #expect(!current.isExpired(now: t0 + 299))
        #expect(current.isExpired(now: t0 + 300))
        current.apply(NowPlayingUpdate(title: "A", playback: .playing, trackKey: "a"), now: t0 + 60)
        #expect(current.playingSince == t0 + 60)
        #expect(!current.isExpired(now: t0 + 10_000))
    }

    @Test func format() {
        #expect(NowPlayingFormat.time(84.9) == "1:24")
        #expect(NowPlayingFormat.time(725) == "12:05")
        #expect(NowPlayingFormat.time(3723) == "1:02:03")
        #expect(NowPlayingFormat.time(-3) == "0:00")
    }
}

@MainActor
final class FakePlayerBridge: PlayerBridge {
    var running: Set<MusicPlayer> = [.spotify, .music]
    var permission: [MusicPlayer: PlayerPermission] = [.spotify: .granted, .music: .granted]
    var askedWithPrompt: [MusicPlayer] = []
    var positionValue: TimeInterval? = 42
    var artwork: URL? = URL(string: "https://i.scdn.co/image/test")
    var sent: [(PlayerCommand, MusicPlayer)] = []
    var opened: [MusicPlayer] = []
    var positionQueries = 0

    func isRunning(_ player: MusicPlayer) -> Bool { running.contains(player) }

    func permission(_ player: MusicPlayer, askIfNeeded: Bool) async -> PlayerPermission {
        guard running.contains(player) else { return .unavailable }
        if askIfNeeded { askedWithPrompt.append(player) }
        let current = permission[player] ?? .notDetermined
        return current == .notDetermined && !askIfNeeded ? .notDetermined : current
    }

    func position(_ player: MusicPlayer) -> TimeInterval? {
        guard running.contains(player) else { return nil }
        positionQueries += 1
        return positionValue
    }

    func artworkURL(_ player: MusicPlayer) -> URL? { player == .spotify && running.contains(player) ? artwork : nil }
    func send(_ command: PlayerCommand, to player: MusicPlayer) { sent.append((command, player)) }
    func open(_ player: MusicPlayer) { opened.append(player) }
}

@MainActor
@Suite struct NowPlayingManagerTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_000_000) }

    let clock = Clock()
    let store: IslandStore
    let bridge = FakePlayerBridge()

    init() {
        let suite = "NowPlayingManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        store = IslandStore(defaults: defaults)
    }

    final class Requests: @unchecked Sendable { var urls: [URL] = [] }
    let requests = Requests()

    /// iTunes Search URLs answer with `search`, everything else with `artwork`.
    func manager(artwork: Data? = nil, search: Data? = nil) -> NowPlayingManager {
        let clock = clock, requests = requests
        return NowPlayingManager(store: store, bridge: bridge, now: { clock.now }, loadData: { url in
            await MainActor.run { requests.urls.append(url) }
            return url.host() == "itunes.apple.com" ? search : artwork
        })
    }

    static let png = NSImage(size: NSSize(width: 2, height: 2), flipped: false) { rect in
        NSColor.red.setFill(); rect.fill(); return true
    }.tiffRepresentation

    func spotify(_ state: String = "Playing", position: Double = 5, track: String = "spotify:track:a") -> NowPlayingUpdate {
        NowPlayingUpdate(player: .spotify, userInfo: NowPlayingSamples.spotify(state: state, position: position, trackID: track))!
    }

    func music(_ state: String = "Playing", name: String = "Song") -> NowPlayingUpdate {
        NowPlayingUpdate(player: .music, userInfo: NowPlayingSamples.music(state: state, name: name))!
    }

    @Test func spotifyShowsInTheIsland() async {
        let manager = manager()
        await manager.handle(spotify(), from: .spotify)
        #expect(store.presentation == .compact)
        #expect(store.primaryActivity?.kind == .music)
        #expect(manager.activity?.state.title == "we shine together")
        #expect(manager.activity?.state.position(now: clock.now) == 5)
        #expect(bridge.positionQueries == 0) // Spotify sends its position
    }

    @Test func musicPositionComesFromAppleEvents() async {
        let manager = manager()
        await manager.handle(music(), from: .music)
        #expect(bridge.positionQueries == 1)
        #expect(manager.activity?.state.position(now: clock.now) == 42)
        #expect(manager.activity?.state.player == .music)
    }

    @Test func spotifyCoverIsLoaded() async throws {
        let png = try #require(NSImage(size: NSSize(width: 2, height: 2), flipped: false) { rect in
            NSColor.red.setFill(); rect.fill(); return true
        }.tiffRepresentation)
        let manager = manager(artwork: png)
        await manager.handle(spotify(), from: .spotify)
        await manager.artworkTask?.value
        #expect(manager.activity?.artwork != nil)

        // A new track drops the old cover until its own arrives.
        bridge.artwork = nil
        await manager.handle(spotify(track: "spotify:track:b"), from: .spotify)
        await manager.artworkTask?.value
        #expect(manager.activity?.artwork == nil)
    }

    @Test func spotifyCoverIsBackAfterSwitchingPlayers() async throws {
        let png = try #require(NSImage(size: NSSize(width: 2, height: 2), flipped: false) { rect in
            NSColor.red.setFill(); rect.fill(); return true
        }.tiffRepresentation)
        let manager = manager(artwork: png)
        await manager.handle(spotify(), from: .spotify)
        await manager.artworkTask?.value
        #expect(manager.activity?.artwork != nil)

        clock.now += 5
        await manager.handle(spotify("Paused"), from: .spotify)
        await manager.handle(music(), from: .music)
        #expect(manager.activity?.state.player == .music)
        #expect(manager.activity?.artwork == nil)

        // Back to Spotify, same track: the cover is there at once, without
        // loading it again.
        bridge.artwork = nil
        clock.now += 5
        await manager.handle(music("Paused"), from: .music)
        await manager.handle(spotify(position: 9), from: .spotify)
        #expect(manager.activity?.state.player == .spotify)
        #expect(manager.activity?.artwork != nil)
    }

    @Test func musicCoverComesFromITunesSearchOncePerTrack() async {
        let search = Data("""
        {"results": [{"artistName": "Nickelback", "trackName": "Song", "collectionName": "Everything Under The Sun",
                      "artworkUrl100": "https://is1-ssl.mzstatic.com/image/thumb/x/100x100bb.jpg"}]}
        """.utf8)
        let manager = manager(artwork: Self.png, search: search)
        await manager.handle(music(), from: .music)
        await manager.artworkTask?.value
        #expect(manager.activity?.artwork != nil)
        #expect(requests.urls.map { $0.host() ?? "" } == ["itunes.apple.com", "is1-ssl.mzstatic.com"])
        #expect(requests.urls.last?.absoluteString.hasSuffix("600x600bb.jpg") == true)

        // Another track and back: the search isn't repeated.
        await manager.handle(music(name: "Other"), from: .music)
        await manager.artworkTask?.value
        await manager.handle(music(), from: .music)
        await manager.artworkTask?.value
        #expect(requests.urls.filter { $0.host() == "itunes.apple.com" }.count == 2)
    }

    @Test func musicTrackNotInTheStoreKeepsThePlaceholder() async {
        let manager = manager(artwork: Self.png, search: Data(#"{"results": []}"#.utf8))
        await manager.handle(music(), from: .music)
        await manager.artworkTask?.value
        #expect(manager.activity?.artwork == nil)
        #expect(requests.urls.count == 1) // no image request
    }

    @Test func askedOnlyWhenPlaybackStarts() async {
        bridge.permission[.music] = .notDetermined
        let manager = manager()
        await manager.handle(music("Paused"), from: .music)
        #expect(bridge.askedWithPrompt.isEmpty)
        #expect(manager.activity == nil)

        bridge.permission[.music] = .granted // the user clicks OK
        await manager.handle(music(), from: .music)
        #expect(bridge.askedWithPrompt == [.music])
        #expect(manager.activity != nil)
    }

    @Test func deniedTurnsOffOnlyThatPlayer() async {
        bridge.permission[.spotify] = .denied
        let manager = manager()
        await manager.handle(spotify(), from: .spotify)
        #expect(manager.activity == nil)
        #expect(manager.permissions[.spotify] == .denied)

        await manager.handle(music(), from: .music)
        #expect(manager.activity?.state.player == .music)

        // Denied stays denied: not asked again on the next song.
        bridge.askedWithPrompt = []
        await manager.handle(spotify(track: "spotify:track:b"), from: .spotify)
        #expect(bridge.askedWithPrompt.isEmpty)
        #expect(manager.activity?.state.player == .music)
    }

    @Test func mostRecentlyStartedPlayerWins() async {
        let manager = manager()
        await manager.handle(music(), from: .music)
        clock.now += 10
        await manager.handle(spotify(), from: .spotify)
        #expect(manager.activity?.state.player == .spotify)

        clock.now += 10
        await manager.handle(spotify("Paused"), from: .spotify)
        #expect(manager.activity?.state.player == .music) // still playing
    }

    @Test func pausedGoesAfterFiveMinutes() async {
        let manager = manager()
        await manager.handle(spotify(), from: .spotify)
        clock.now += 10
        await manager.handle(spotify("Paused"), from: .spotify)
        clock.now += 299
        manager.refresh()
        #expect(manager.activity != nil)
        clock.now += 1
        manager.refresh()
        #expect(manager.activity == nil)
        #expect(store.presentation == .idle)
    }

    @Test func stoppedRemovesIt() async {
        let manager = manager()
        await manager.handle(spotify(), from: .spotify)
        await manager.handle(NowPlayingUpdate(player: .spotify, userInfo: ["Player State": "Stopped"])!, from: .spotify)
        #expect(manager.activity == nil)
    }

    @Test func controlsGoToTheShownPlayer() async {
        let manager = manager()
        await manager.handle(music(), from: .music)
        manager.send(.next)
        manager.send(.playPause)
        #expect(bridge.sent.map(\.0) == [.next, .playPause])
        #expect(bridge.sent.allSatisfy { $0.1 == .music })
        #expect(manager.activity?.state.isPlaying == false) // answered right away

        manager.openPlayer()
        #expect(bridge.opened == [.music])
    }

    @Test func noAppleEventsToPlayersThatAreNotRunning() async {
        bridge.running = []
        let manager = manager()
        await manager.handle(music(), from: .music)
        #expect(bridge.positionQueries == 0)
        #expect(manager.activity == nil) // permission can't be checked
    }

    @Test func burstWhilePermissionIsCheckedKeepsTheNewest() async {
        let manager = manager()
        // Music sends "Paused" and "Playing" within milliseconds; the second
        // arrives while the first is still waiting for the permission check.
        async let first: Void = manager.handle(music("Paused"), from: .music)
        async let second: Void = manager.handle(music("Playing"), from: .music)
        _ = await (first, second)
        #expect(manager.activity?.state.isPlaying == true)
    }

    @Test func switchesWhenTheOtherPlayerStarts() async {
        let manager = manager()
        await manager.handle(music(), from: .music)
        clock.now += 5
        await manager.handle(music("Paused"), from: .music)
        clock.now += 5
        await manager.handle(spotify(), from: .spotify)
        #expect(manager.activity?.state.player == .spotify)
        clock.now += 5
        await manager.handle(spotify("Paused"), from: .spotify)
        await manager.handle(music(), from: .music)
        #expect(manager.activity?.state.player == .music)
    }

    @Test func accessibility() async {
        let manager = manager()
        await manager.handle(music("Paused"), from: .music)
        #expect(manager.activity?.accessibilityLabel == "Music, Song by Nickelback, paused, Music")
    }
}
