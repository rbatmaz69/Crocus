import SwiftUI

/// The song playing in Spotify or Music. One activity for both players;
/// the manager decides which one it shows.
@MainActor
@Observable
final class NowPlayingActivity: IslandActivity {
    private(set) var state: NowPlayingState
    private(set) var artwork: NSImage?
    @ObservationIgnored private var artworkKey: String?

    let startedAt: Date

    @ObservationIgnored var onCommand: ((PlayerCommand) -> Void)?
    @ObservationIgnored var onOpenPlayer: (() -> Void)?

    init(state: NowPlayingState, startedAt: Date) {
        self.state = state
        self.startedAt = startedAt
    }

    func update(_ state: NowPlayingState) {
        if state.trackKey != artworkKey, artwork != nil { artwork = nil }
        self.state = state
    }

    func setArtwork(_ image: NSImage, for trackKey: String) {
        guard trackKey == state.trackKey, !(artworkKey == trackKey && artwork === image) else { return }
        artworkKey = trackKey
        artwork = image
    }

    // MARK: IslandActivity

    var id: String { NowPlayingManager.activityID }
    var kind: ActivityKind { .music }

    var accessibilityLabel: String {
        var parts = ["Music", state.artist.map { "\(state.title) by \($0)" } ?? state.title]
        if !state.isPlaying { parts.append("paused") }
        parts.append(state.player.displayName)
        return parts.joined(separator: ", ")
    }

    var compactLeading: AnyView { AnyView(NowPlayingCover(activity: self, size: 24, radius: 6)) }
    var compactTrailing: AnyView { AnyView(NowPlayingVisualizer(isPlaying: state.isPlaying)) }
    var minimal: AnyView { AnyView(NowPlayingCover(activity: self, size: 22, radius: 6)) }
    var expandedSource: AnyView { AnyView(Text("Music")) }
    var expandedStatus: AnyView { AnyView(Text(state.player.displayName)) }
    var expandedContent: AnyView { AnyView(NowPlayingCard(activity: self)) }
}
