import SwiftUI

/// Content of the compact state, laid out for the given mode. Sample content
/// in DEBUG until real activities exist.
struct IslandCompactContent: View {
    let model: OverlayPanelModel
    let metrics: IslandLayoutMetrics

    var body: some View {
        let reduced = metrics.trailingWingWidth < CrocusMetrics.notch.wingWidth
        CompactLayout(metrics: metrics) {
            #if DEBUG
            DebugIslandSamples.compactLeading
            #endif
        } trailing: {
            #if DEBUG
            DebugIslandSamples.compactTrailing(reduced: reduced)
            #endif
        }
    }
}

/// Content of the expanded state; reports its natural height to the model so
/// the island can follow it.
struct IslandExpandedContent: View {
    let model: OverlayPanelModel
    let metrics: IslandLayoutMetrics

    var body: some View {
        ExpandedLayout(metrics: metrics) { model.expandedContentHeight = $0 } source: {
            #if DEBUG
            Text("build.sh · Terminal")
            #endif
        } status: {
            #if DEBUG
            Text("2:14 ago")
            #endif
        } content: {
            #if DEBUG
            DebugIslandSamples.expandedContent(large: model.usesLargeSample)
            #endif
        }
    }
}
