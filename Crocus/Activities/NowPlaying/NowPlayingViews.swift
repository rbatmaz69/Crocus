import SwiftUI

/// Cover with rounded corners; a note symbol when there is none (Music –
/// the sandbox doesn't allow reading its artwork – or still loading).
struct NowPlayingCover: View {
    let activity: NowPlayingActivity
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Group {
            if let artwork = activity.artwork {
                Image(nsImage: artwork).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
            } else {
                shape.fill(CrocusColors.surface)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.45, weight: .semibold))
                            .foregroundStyle(CrocusColors.secondary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .accessibilityHidden(true)
    }
}

/// Five 3 pt bars. Crocus can't hear the audio, so they move on their own
/// while playing; still while paused or with Reduce Motion.
struct NowPlayingVisualizer: View {
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let restingHeights: [CGFloat] = [6, 12, 16, 10, 7]

    var body: some View {
        let animates = isPlaying && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: !animates)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(CrocusColors.primary.opacity(isPlaying ? 1 : 0.5))
                        .frame(width: 3, height: animates ? Self.height(index, at: t) : (isPlaying ? Self.restingHeights[index] : 3))
                }
            }
            .frame(height: 18)
            .animation(.easeInOut(duration: 0.12), value: t)
        }
        .accessibilityHidden(true)
    }

    /// Smooth, different-looking movement per bar, 4–17 pt.
    static func height(_ index: Int, at time: TimeInterval) -> CGFloat {
        let speeds = [5.1, 7.3, 6.2, 8.9, 5.7]
        let phase = Double(index) * 1.7
        let wave = (sin(time * speeds[index] + phase) + sin(time * speeds[(index + 2) % 5] * 0.6)) / 2
        return 4 + 13 * CGFloat((wave + 1) / 2)
    }
}

/// Expanded: cover (opens the player), title, artist, visualizer; 4 pt
/// white progress bar with "1:24" and "−2:27"; previous / play-pause /
/// next.
struct NowPlayingCard: View {
    let activity: NowPlayingActivity

    var body: some View {
        let state = activity.state
        HStack(spacing: 14) {
            Button { activity.onOpenPlayer?() } label: {
                NowPlayingCover(activity: activity, size: 60, radius: 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(state.player.displayName)")

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(CrocusTypography.title.font())
                    .lineLimit(1)
                if let artist = state.artist {
                    Text(artist)
                        .font(CrocusTypography.status.font())
                        .foregroundStyle(CrocusColors.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            NowPlayingVisualizer(isPlaying: state.isPlaying)
        }
        .foregroundStyle(CrocusColors.primary)

        if state.duration != nil {
            NowPlayingProgress(state: state)
        }

        HStack(spacing: 28) {
            control("backward.fill", size: 36, label: "Previous") { activity.onCommand?(.previous) }
            control(state.isPlaying ? "pause.fill" : "play.fill", size: 44, label: state.isPlaying ? "Pause" : "Play") {
                activity.onCommand?(.playPause)
            }
            control("forward.fill", size: 36, label: "Next") { activity.onCommand?(.next) }
        }
        .frame(maxWidth: .infinity)
    }

    private func control(_ symbol: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size == 44 ? 22 : 16, weight: .semibold))
                .foregroundStyle(CrocusColors.primary)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// "1:24" ▬▬▬▬▬▬ "−2:27", moving on locally once per second.
struct NowPlayingProgress: View {
    let state: NowPlayingState

    var body: some View {
        TimelineView(.periodic(from: state.positionDate, by: 1)) { context in
            let now = state.isPlaying ? context.date : state.positionDate
            HStack(spacing: 8) {
                Text(NowPlayingFormat.time(state.position(now: now)))
                IslandProgressBar(progress: state.progress(now: now) ?? 0, tint: CrocusColors.primary, height: 4)
                Text("−" + NowPlayingFormat.time(state.remaining(now: now) ?? 0))
            }
            .font(CrocusTypography.caption.font())
            .foregroundStyle(CrocusColors.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(NowPlayingFormat.time(state.position(now: now))) of \(NowPlayingFormat.time(state.duration ?? 0))")
        }
    }
}

enum NowPlayingFormat {
    /// "1:24", "12:05", "1:02:03".
    static func time(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded(.down))
        let hours = total / 3600, minutes = total / 60 % 60, secs = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }
}
