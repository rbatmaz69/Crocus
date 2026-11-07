import SwiftUI

/// Sample activities: the debug menu uses them to exercise priorities, the
/// minimal state and event overlays; the onboarding's island demo shows them.
@MainActor
final class SampleActivity: IslandActivity {
    let id: String
    let kind: ActivityKind
    let startedAt = Date()
    let title: String
    let accessibilityLabel: String
    let compactLeading: AnyView
    let compactTrailing: AnyView
    let compactTrailingReduced: AnyView
    let expandedSource: AnyView
    let expandedStatus: AnyView
    let expandedContent: AnyView

    init(
        kind: ActivityKind,
        title: String,
        accessibilityLabel: String,
        compactLeading: some View,
        compactTrailing: some View,
        compactTrailingReduced: (some View)? = nil as EmptyView?,
        expandedSource: String,
        expandedStatus: String,
        @ViewBuilder expandedContent: () -> some View
    ) {
        self.id = "sample.\(kind.rawValue)"
        self.kind = kind
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.compactLeading = AnyView(compactLeading)
        self.compactTrailing = AnyView(compactTrailing)
        self.compactTrailingReduced = compactTrailingReduced.map { AnyView($0) } ?? AnyView(compactTrailing)
        self.expandedSource = AnyView(Text(expandedSource))
        self.expandedStatus = AnyView(Text(expandedStatus))
        self.expandedContent = AnyView(expandedContent())
    }
}

enum SampleActivities {
    @MainActor
    static func make(_ kind: ActivityKind) -> SampleActivity {
        switch kind {
        case .timer: timer
        case .music: music
        case .cameraMicrophone: camera
        case .liveActivity: liveActivity
        case .calendar: calendar
        case .download: download
        }
    }

    @MainActor static var timer: SampleActivity {
        SampleActivity(
            kind: .timer, title: "Timer",
            accessibilityLabel: "Timer, 4 minutes 32 seconds remaining",
            compactLeading: IslandCompactSymbol(systemName: "timer"),
            compactTrailing: IslandCompactValue(text: "04:32"),
            compactTrailingReduced: IslandProgressRing(progress: 0.45),
            expandedSource: "Timer", expandedStatus: "Running"
        ) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("04:32").font(CrocusTypography.display.font())
                    Text("Timer · 10:00 · ends 14:37")
                        .font(CrocusTypography.status.font())
                        .foregroundStyle(CrocusColors.secondary)
                }
                Spacer()
                IslandButton(title: "Pause")
            }
            IslandProgressBar(progress: 0.45, height: 4)
        }
    }

    @MainActor static var music: SampleActivity {
        SampleActivity(
            kind: .music, title: "Music",
            accessibilityLabel: "Music, Midnight Avenue by Lumen Park",
            compactLeading: Cover(size: 24, radius: 6),
            compactTrailing: Visualizer(),
            expandedSource: "Music", expandedStatus: "Spotify"
        ) {
            HStack(spacing: 14) {
                Cover(size: 60, radius: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Midnight Avenue").font(CrocusTypography.title.font())
                    Text("Lumen Park").font(CrocusTypography.status.font()).foregroundStyle(CrocusColors.secondary)
                }
                Spacer()
                Visualizer()
            }
            IslandProgressBar(progress: 0.37, tint: CrocusColors.primary, height: 4)
        }
    }

    @MainActor static var camera: SampleActivity {
        SampleActivity(
            kind: .cameraMicrophone, title: "Camera",
            accessibilityLabel: "Camera active",
            compactLeading: IslandCompactSymbol(systemName: "video.fill", color: CrocusColors.positive),
            compactTrailing: Circle().fill(CrocusColors.positive).frame(width: 6, height: 6),
            expandedSource: "Privacy", expandedStatus: "Now"
        ) {
            HStack(spacing: 12) {
                IslandCompactSymbol(systemName: "video.fill", color: CrocusColors.positive)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Camera active").font(CrocusTypography.title.font())
                    Text("For 12 min · used by an app").font(CrocusTypography.status.font()).foregroundStyle(CrocusColors.secondary)
                }
                Spacer()
                Circle().fill(CrocusColors.positive).frame(width: 6, height: 6)
            }
            IslandButton(title: "Privacy Settings…")
        }
    }

    @MainActor static var liveActivity: SampleActivity {
        SampleActivity(
            kind: .liveActivity, title: "Build",
            accessibilityLabel: "Build running, 40 percent, compiling 128 of 320 files",
            compactLeading: TerminalIcon(size: 22),
            compactTrailing: IslandProgressRing(progress: 0.4),
            expandedSource: "build.sh · Terminal", expandedStatus: "2:14 ago"
        ) {
            HStack(spacing: 12) {
                TerminalIcon(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Build running").font(CrocusTypography.title.font())
                    Text("Compiling 128 of 320 files").font(CrocusTypography.status.font()).foregroundStyle(CrocusColors.secondary)
                }
                Spacer()
                Text("40 %").font(CrocusTypography.value.font())
            }
            IslandProgressBar(progress: 0.4)
            HStack(spacing: 8) {
                IslandButton(title: "Open Log", primary: true)
                IslandButton(title: "Hide")
            }
        }
    }

    @MainActor static var calendar: SampleActivity {
        SampleActivity(
            kind: .calendar, title: "Calendar",
            accessibilityLabel: "Sprint Review in 5 minutes",
            compactLeading: IslandCompactSymbol(systemName: "calendar"),
            compactTrailing: IslandCompactValue(text: "5 min"),
            compactTrailingReduced: IslandCompactSymbol(systemName: "video.fill"),
            expandedSource: "Calendar", expandedStatus: "In 5 min"
        ) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(Color.purple).frame(width: 4, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sprint Review").font(CrocusTypography.title.font())
                    Text("14:30–15:00 · Video call").font(CrocusTypography.status.font()).foregroundStyle(CrocusColors.secondary)
                }
                Spacer()
                IslandButton(title: "Join", primary: true)
            }
        }
    }

    @MainActor static var download: SampleActivity {
        SampleActivity(
            kind: .download, title: "Download",
            accessibilityLabel: "Download, 62 percent",
            compactLeading: IslandCompactSymbol(systemName: "arrow.down.circle"),
            compactTrailing: IslandProgressRing(progress: 0.62),
            expandedSource: "Downloads", expandedStatus: "1 file"
        ) {
            HStack {
                Text("Xcode.xip").font(CrocusTypography.title.font())
                Spacer()
                Text("62 %").font(CrocusTypography.value.font())
            }
            IslandProgressBar(progress: 0.62)
        }
    }
}

private struct Cover: View {
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
    }
}

private struct Visualizer: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach([6.0, 12, 16, 10, 7], id: \.self) { height in
                Capsule().fill(CrocusColors.primary).frame(width: 3, height: height)
            }
        }
    }
}

private struct TerminalIcon: View {
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
            .fill(CrocusColors.surface)
            .frame(width: size, height: size)
            .overlay(Image(systemName: "terminal.fill").font(.system(size: size * 0.45)).foregroundStyle(CrocusColors.primary))
    }
}
