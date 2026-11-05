#if DEBUG
import SwiftUI

/// Debug-only island states and sample content, so shapes and springs can be
/// checked before the state machine (#7) and real activities exist.
enum DebugIslandState: String, CaseIterable, Identifiable {
    case idle
    case compact
    case expandedSmall
    case expandedLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idle: "Idle"
        case .compact: "Compact"
        case .expandedSmall: "Expanded (small)"
        case .expandedLarge: "Expanded (large)"
        }
    }

    var presentation: IslandPresentation {
        switch self {
        case .idle: .idle
        case .compact: .compact
        case .expandedSmall, .expandedLarge: .expanded
        }
    }

    var usesLargeSample: Bool { self == .expandedLarge }
}

enum DebugIslandSamples {
    static var compactLeading: some View {
        Image(systemName: "timer")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(CrocusColors.primary)
            .frame(width: CrocusMetrics.Compact.symbolSize, height: CrocusMetrics.Compact.symbolSize)
    }

    @ViewBuilder
    static func compactTrailing(reduced: Bool) -> some View {
        if reduced {
            ProgressRing(progress: 0.45)
        } else {
            Text("04:32")
                .font(CrocusTypography.title.font(inCompactIsland: true))
                .monospacedDigit()
                .foregroundStyle(CrocusColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    static func expandedContent(large: Bool) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CrocusColors.surface)
                .frame(width: 34, height: 34)
                .overlay(Image(systemName: "terminal.fill").font(.system(size: 15)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Build running").font(CrocusTypography.title.font())
                Text("Compiling 128 of 320 files")
                    .font(CrocusTypography.status.font())
                    .foregroundStyle(CrocusColors.secondary)
            }
            Spacer()
            Text("40 %").font(CrocusTypography.value.font())
        }
        .foregroundStyle(CrocusColors.primary)

        ProgressBar(progress: 0.4)

        HStack(spacing: 8) {
            CapsuleButton(title: "Open Log", primary: true)
            CapsuleButton(title: "Hide", primary: false)
        }

        if large {
            PrivacyRow(symbol: "video.fill", title: "Camera active", color: CrocusColors.positive)
            PrivacyRow(symbol: "mic.fill", title: "Microphone active", color: CrocusColors.microphone)
        }
    }
}

private struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(CrocusColors.progress.opacity(CrocusColors.progressTrackOpacity), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(CrocusColors.progress, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
    }
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(CrocusColors.surface)
                Capsule().fill(CrocusColors.progress).frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 6)
    }
}

private struct CapsuleButton: View {
    let title: String
    let primary: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(primary ? CrocusColors.island : CrocusColors.primary)
            .padding(.horizontal, 14)
            .frame(height: CrocusMetrics.Expanded.buttonHeight)
            .background(Capsule().fill(primary ? CrocusColors.primary : CrocusColors.surface))
    }
}

private struct PrivacyRow: View {
    let symbol: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 34, height: 34)
                .overlay(Image(systemName: symbol).foregroundStyle(color))
            Text(title).font(CrocusTypography.title.font())
            Spacer()
            Circle().fill(color).frame(width: 6, height: 6)
        }
        .foregroundStyle(CrocusColors.primary)
    }
}
#endif
