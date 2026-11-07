import SwiftUI

/// Camera and/or microphone in use; fixed on top of the island.
@MainActor
@Observable
final class PrivacyActivity: IslandActivity {
    private(set) var state: PrivacyState
    let startedAt: Date
    @ObservationIgnored var onOpenSettings: (() -> Void)?

    init(state: PrivacyState, startedAt: Date) {
        self.state = state
        self.startedAt = startedAt
    }

    func update(_ state: PrivacyState) {
        if state != self.state { self.state = state }
    }

    // MARK: IslandActivity

    var id: String { PrivacyManager.activityID }
    var kind: ActivityKind { .cameraMicrophone }
    var accessibilityLabel: String { PrivacyFormat.accessibilityLabel(state.shown) }

    var compactLeading: AnyView { AnyView(PrivacySymbol(device: state.isShown(.camera) ? .camera : .microphone)) }
    var compactTrailing: AnyView { AnyView(PrivacyDots(devices: state.shown)) }
    var minimal: AnyView { compactLeading }
    var expandedSource: AnyView { AnyView(Text("Privacy")) }
    var expandedStatus: AnyView { AnyView(Text("Now")) }
    var expandedContent: AnyView { AnyView(PrivacyCard(activity: self)) }
}

extension PrivacyState.Device {
    /// Signal colours – only ever for dots and symbols, never areas.
    var color: Color {
        switch self {
        case .camera: CrocusColors.positive
        case .microphone: CrocusColors.microphone
        }
    }

    var symbol: String {
        switch self {
        case .camera: "video.fill"
        case .microphone: "mic.fill"
        }
    }
}

struct PrivacySymbol: View {
    let device: PrivacyState.Device

    var body: some View {
        IslandCompactSymbol(systemName: device.symbol, color: device.color)
    }
}

/// One 6 pt dot per device in use.
struct PrivacyDots: View {
    let devices: [PrivacyState.Device]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(devices, id: \.self) { device in
                Circle().fill(device.color).frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Expanded (board 07 · 4e): a row per device, then "Privacy Settings…".
struct PrivacyCard: View {
    let activity: PrivacyActivity

    var body: some View {
        let state = activity.state
        TimelineView(.periodic(from: activity.startedAt, by: 60)) { context in
            VStack(alignment: .leading, spacing: 12) {
                ForEach(state.shown, id: \.self) { device in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(CrocusColors.surface)
                            .frame(width: 34, height: 34)
                            .overlay(Image(systemName: device.symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(device.color))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(PrivacyFormat.title(device))
                                .islandFont(CrocusTypography.title)
                            Text(PrivacyFormat.subtitle(since: state.use(device)?.since, now: context.date))
                                .islandFont(CrocusTypography.status)
                                .foregroundStyle(.islandSecondary)
                        }
                        Spacer(minLength: 8)
                        Circle().fill(device.color).frame(width: 6, height: 6).accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .foregroundStyle(CrocusColors.primary)
        }
        IslandButton(title: "Privacy Settings…") { activity.onOpenSettings?() }
    }
}
