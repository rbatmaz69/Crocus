import Foundation

/// What a player is playing, as a pure value. The position is stored with
/// the time it was read and moved on locally, so nothing has to be polled
/// every second.
struct NowPlayingState: Equatable, Sendable {
    enum Playback: String, Equatable, Sendable {
        case playing
        case paused
        case stopped
    }

    let player: MusicPlayer
    var title: String
    var artist: String?
    var album: String?
    /// Track length; `nil` for streams without one.
    var duration: TimeInterval?
    var playback: Playback
    /// Position at `positionDate`.
    var position: TimeInterval
    var positionDate: Date
    /// Identifies the track (Spotify's track ID, or title + artist + album).
    var trackKey: String
    /// When playback last started; the most recent player wins.
    var playingSince: Date?
    /// When playback last changed; a paused player goes after 5 min.
    var lastChange: Date

    /// A paused player stays in the island this long.
    static let pausedTimeout: TimeInterval = 5 * 60

    var isPlaying: Bool { playback == .playing }

    func position(now: Date) -> TimeInterval {
        let moved = isPlaying ? position + max(now.timeIntervalSince(positionDate), 0) : position
        guard let duration else { return max(moved, 0) }
        return min(max(moved, 0), duration)
    }

    func remaining(now: Date) -> TimeInterval? {
        duration.map { max($0 - position(now: now), 0) }
    }

    func progress(now: Date) -> Double? {
        guard let duration, duration > 0 else { return nil }
        return position(now: now) / duration
    }

    /// Paused for longer than 5 min (or stopped).
    func isExpired(now: Date) -> Bool {
        switch playback {
        case .playing: false
        case .paused: now.timeIntervalSince(lastChange) >= Self.pausedTimeout
        case .stopped: true
        }
    }

    /// Applies a notification from the player. `position` is `nil` when the
    /// player didn't send one (Music); the local one then moves on, and
    /// starts at 0 for a new track.
    mutating func apply(_ update: NowPlayingUpdate, now: Date) {
        let newTrack = update.trackKey != trackKey
        let current = position(now: now)
        title = update.title ?? title
        artist = update.artist ?? artist
        album = update.album ?? album
        duration = update.duration ?? (newTrack ? nil : duration)
        trackKey = update.trackKey
        if update.playback != playback {
            if update.playback == .playing { playingSince = now }
            lastChange = now
        }
        playback = update.playback
        position = update.position ?? (newTrack ? 0 : current)
        positionDate = now
    }

    /// Position read via Apple Events.
    mutating func setPosition(_ value: TimeInterval, now: Date) {
        position = value
        positionDate = now
    }

    init(player: MusicPlayer, update: NowPlayingUpdate, now: Date) {
        self.player = player
        title = update.title ?? ""
        artist = update.artist
        album = update.album
        duration = update.duration
        playback = update.playback
        position = update.position ?? 0
        positionDate = now
        trackKey = update.trackKey
        playingSince = update.playback == .playing ? now : nil
        lastChange = now
    }
}

/// One notification from a player, parsed.
struct NowPlayingUpdate: Equatable, Sendable {
    var title: String?
    var artist: String?
    var album: String?
    var duration: TimeInterval?
    var position: TimeInterval?
    var playback: NowPlayingState.Playback
    var trackKey: String

    /// `userInfo` of `com.spotify.client.PlaybackStateChanged` or
    /// `com.apple.Music.playerInfo`. Both send "Player State" and "Name",
    /// "Artist", "Album"; Spotify sends "Duration" (ms), "Playback Position"
    /// (s) and "Track ID", Music "Total Time" (ms).
    init?(player: MusicPlayer, userInfo: [AnyHashable: Any]) {
        guard let state = userInfo["Player State"] as? String else { return nil }
        switch state.lowercased() {
        case "playing": playback = .playing
        case "paused": playback = .paused
        case "stopped": playback = .stopped
        default: return nil
        }
        title = Self.text(userInfo["Name"])
        artist = Self.text(userInfo["Artist"])
        album = Self.text(userInfo["Album"])
        let milliseconds = Self.number(userInfo[player == .spotify ? "Duration" : "Total Time"])
        duration = milliseconds.flatMap { $0 > 0 ? $0 / 1000 : nil }
        position = player == .spotify ? Self.number(userInfo["Playback Position"]) : nil
        let id = Self.text(userInfo["Track ID"])
        trackKey = id ?? [title, artist, album].map { $0 ?? "" }.joined(separator: "\u{1F}")
        if playback != .stopped, title == nil { return nil }
    }

    init(title: String?, artist: String? = nil, album: String? = nil, duration: TimeInterval? = nil,
         position: TimeInterval? = nil, playback: NowPlayingState.Playback, trackKey: String) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.playback = playback
        self.trackKey = trackKey
    }

    private static func text(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: number.doubleValue.isFinite ? number.doubleValue : nil
        case let string as String: Double(string)
        default: nil
        }
    }
}
