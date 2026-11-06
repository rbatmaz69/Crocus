import Foundation

/// The players Crocus can show and control via Apple Events.
enum MusicPlayer: String, CaseIterable, Sendable {
    case spotify
    case music

    var bundleID: String {
        switch self {
        case .spotify: "com.spotify.client"
        case .music: "com.apple.Music"
        }
    }

    var displayName: String {
        switch self {
        case .spotify: "Spotify"
        case .music: "Music"
        }
    }

    /// Posted by the player on every change, with the track in `userInfo`.
    var notificationName: Notification.Name {
        switch self {
        case .spotify: Notification.Name("com.spotify.client.PlaybackStateChanged")
        case .music: Notification.Name("com.apple.Music.playerInfo")
        }
    }

    init?(bundleID: String) {
        guard let player = Self.allCases.first(where: { $0.bundleID == bundleID }) else { return nil }
        self = player
    }
}

/// Play/pause, next, previous.
enum PlayerCommand: String, CaseIterable, Sendable {
    case playPause
    case next
    case previous

    /// The AppleScript command – the same for Spotify and Music.
    var appleScript: String {
        switch self {
        case .playPause: "playpause"
        case .next: "next track"
        case .previous: "previous track"
        }
    }
}

/// Whether Crocus may send Apple Events to a player (Privacy & Security →
/// Automation).
enum PlayerPermission: Equatable, Sendable {
    case granted
    case denied
    /// The user hasn't been asked yet.
    case notDetermined
    /// Can't be checked: the player isn't running.
    case unavailable
}
