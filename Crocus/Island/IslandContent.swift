import SwiftUI

/// Content of the compact state: the event, or the main activity.
struct IslandCompactContent: View {
    let model: OverlayPanelModel
    let metrics: IslandLayoutMetrics

    var body: some View {
        let store = model.store
        let reduced = metrics.trailingWingWidth < CrocusMetrics.notch.wingWidth

        CompactLayout(metrics: metrics) {
            if let event = store.currentEvent {
                event.compactLeading
            } else if let activity = store.compactContentActivity {
                activity.compactLeading
            }
        } trailing: {
            if let event = store.currentEvent {
                event.compactTrailing
            } else if let activity = store.compactContentActivity {
                reduced ? activity.compactTrailingReduced : activity.compactTrailing
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(store.accessibilityLabel)
    }
}

/// Content of the expanded state: one card per activity in priority order.
/// With several cards the header reads "Activities · 2 of 3" and page dots
/// sit below the card. Reports its natural height so the island follows it.
struct IslandExpandedContent: View {
    let model: OverlayPanelModel
    let metrics: IslandLayoutMetrics

    var body: some View {
        let store = model.store
        let activity = store.expandedContentActivity
        let position = store.cardPosition
        let isStack = (position?.count ?? 0) > 1

        ExpandedLayout(metrics: metrics) { model.expandedContentHeight = $0 } source: {
            if isStack {
                Text("Activities")
            } else {
                activity?.expandedSource
            }
        } status: {
            if isStack, let position {
                Text("\(position.index + 1) of \(position.count)")
                    .monospacedDigit()
            } else {
                activity?.expandedStatus
            }
        } content: {
            Group {
                if let activity {
                    VStack(alignment: .leading, spacing: CrocusMetrics.Expanded.rowSpacing) {
                        activity.expandedContent
                    }
                    .id(activity.id)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: activity?.id)

            if isStack, let position {
                PageDots(index: position.index, count: position.count) { store.showCard(at: $0) }
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
