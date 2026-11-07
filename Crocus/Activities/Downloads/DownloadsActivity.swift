import SwiftUI

/// Running (and just finished) downloads as one activity.
@MainActor
@Observable
final class DownloadsActivity: IslandActivity {
    private(set) var items: [DownloadsState.Item]
    /// Overall progress of the running ones; `nil` if a size is unknown.
    private(set) var overall: Double?
    let startedAt: Date

    init(items: [DownloadsState.Item], overall: Double?, startedAt: Date) {
        self.items = items
        self.overall = overall
        self.startedAt = startedAt
    }

    func update(items: [DownloadsState.Item], overall: Double?) {
        if items != self.items { self.items = items }
        if overall != self.overall { self.overall = overall }
    }

    /// Nothing running any more (finished or cancelled).
    var allEnded: Bool { items.allSatisfy { $0.finishedAt != nil } }
    /// ✕ only if every download was cancelled; ✓ otherwise.
    var endResult: LiveActivityResult { items.allSatisfy(\.isCancelled) ? .failure : .success }

    // MARK: IslandActivity

    var id: String { DownloadsManager.activityID }
    var kind: ActivityKind { .download }
    var accessibilityLabel: String { DownloadsFormat.accessibilityLabel(items, overall: overall) }

    var compactLeading: AnyView { AnyView(IslandCompactSymbol(systemName: "arrow.down.circle")) }
    var compactTrailing: AnyView { AnyView(DownloadsIndicator(activity: self)) }
    var expandedSource: AnyView { AnyView(Text("Downloads")) }
    var expandedStatus: AnyView { AnyView(Text(DownloadsFormat.count(items.count))) }
    var expandedContent: AnyView { AnyView(DownloadsCard(activity: self)) }
}

/// Right wing: overall progress ring, a spinner when a size is unknown,
/// ✓ / ✕ once nothing runs any more.
struct DownloadsIndicator: View {
    let activity: DownloadsActivity

    var body: some View {
        if activity.allEnded {
            LiveActivityResultSymbol(result: activity.endResult)
        } else if let overall = activity.overall {
            IslandProgressRing(progress: overall)
        } else {
            IslandSpinner()
        }
    }
}

/// Expanded: up to three downloads – name, size, percentage, bar – and
/// "+2 more".
struct DownloadsCard: View {
    static let maxRows = 3
    let activity: DownloadsActivity

    var body: some View {
        let items = activity.items
        ForEach(items.prefix(Self.maxRows), id: \.id) { item in
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .islandFont(CrocusTypography.title)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(DownloadsFormat.sizeLine(item))
                            .islandFont(CrocusTypography.status)
                            .foregroundStyle(CrocusColors.secondary)
                    }
                    Spacer(minLength: 8)
                    if item.finishedAt != nil {
                        LiveActivityResultSymbol(result: item.isCancelled ? .failure : .success)
                    } else if let fraction = item.fraction {
                        Text(DownloadsFormat.percent(fraction)).islandFont(CrocusTypography.value)
                    } else {
                        IslandSpinner()
                    }
                }
                if item.finishedAt == nil, let fraction = item.fraction {
                    IslandProgressBar(progress: fraction)
                }
            }
            .foregroundStyle(CrocusColors.primary)
            .accessibilityElement(children: .combine)
        }
        if items.count > Self.maxRows {
            Text("+\(items.count - Self.maxRows) more")
                .islandFont(CrocusTypography.status)
                .foregroundStyle(CrocusColors.secondary)
        }
    }
}
