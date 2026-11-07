import SwiftUI

/// Building blocks for activity content, styled after the spec.

/// Circular progress, 20 pt, 3 pt stroke, system blue (compact right wing).
struct IslandProgressRing: View {
    let progress: Double
    var tint: Color = CrocusColors.progress
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(CrocusColors.progressTrackOpacity(increasedContrast: contrast == .increased)), lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
        .animation(.easeInOut(duration: 0.3), value: progress)
    }
}

/// Indeterminate progress: a rotating arc in the ring's size and colour.
struct IslandSpinner: View {
    var tint: Color = CrocusColors.progress
    @State private var rotation: Double = 0
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(CrocusColors.progressTrackOpacity(increasedContrast: contrast == .increased)), lineWidth: 3)
            Circle()
                .trim(from: 0, to: 0.28)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(rotation))
        }
        .frame(width: 20, height: 20)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

/// Linear progress bar on the surface colour (expanded).
struct IslandProgressBar: View {
    let progress: Double
    var tint: Color = CrocusColors.progress
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(CrocusColors.surface)
                Capsule().fill(tint).frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
    }
}

/// Capsule button; the primary action is filled white.
struct IslandButton: View {
    let title: String
    var primary = false
    /// Optional SF Symbol before the title, e.g. `video.fill` for "Join".
    var systemImage: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .islandFont(CrocusTypography.button)
            .foregroundStyle(primary ? CrocusColors.island : CrocusColors.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: CrocusMetrics.Expanded.buttonHeight)
            .background(Capsule().fill(primary ? CrocusColors.primary : CrocusColors.surface))
        }
        .buttonStyle(.plain)
    }
}

/// Symbol in the compact left wing.
struct IslandCompactSymbol: View {
    let systemName: String
    var color: Color = CrocusColors.primary

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: CrocusMetrics.Compact.symbolSize, height: CrocusMetrics.Compact.symbolSize)
    }
}

/// Value in the compact right wing (Semibold 15, tabular digits).
struct IslandCompactValue: View {
    let text: String
    var color: Color = CrocusColors.primary
    /// Secondary instead of `color` (e.g. a paused timer); follows Increase Contrast.
    var dimmed = false

    var body: some View {
        Text(text)
            .islandFont(CrocusTypography.title, inCompactIsland: true)
            .monospacedDigit()
            .foregroundStyle(dimmed ? AnyShapeStyle(IslandSecondaryStyle()) : AnyShapeStyle(color))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// Round 44 pt control, e.g. Pause / Stop on the timer (expanded).
struct IslandCircleButton: View {
    let systemName: String
    let accessibilityLabel: String
    var action: () -> Void = {}

    static let size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CrocusColors.primary)
                .frame(width: Self.size, height: Self.size)
                .background(Circle().fill(CrocusColors.surface))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
