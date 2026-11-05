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

/// Content of the expanded state; reports its natural height to the model so
/// the island can follow it.
struct IslandExpandedContent: View {
    let model: OverlayPanelModel
    let metrics: IslandLayoutMetrics

    var body: some View {
        let activity = model.store.expandedContentActivity
        ExpandedLayout(metrics: metrics) { model.expandedContentHeight = $0 } source: {
            activity?.expandedSource
        } status: {
            activity?.expandedStatus
        } content: {
            activity?.expandedContent
        }
    }
}
