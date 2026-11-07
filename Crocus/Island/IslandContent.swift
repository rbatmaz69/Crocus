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
                // C1: one bounce once the island has settled.
                activity.compactLeading
                    .symbolEffect(.bounce, value: model.arrivalBounce)
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
            CardStrip(model: model, metrics: metrics, activity: activity, position: position)

            if isStack, let position {
                PageDots(index: position.index, count: position.count) { model.showCard(at: $0) }
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// The cards of the expanded island side by side (C4): the strip sits at
/// `cardStripPosition` – it follows the fingers while swiping and settles on
/// the card spring. Only the current card sets the height, so the island
/// follows the new card once it has switched; the others hang beside it,
/// cut off by the island's shape. Reduce Motion: cards cross-fade (150 ms).
private struct CardStrip: View {
    let model: OverlayPanelModel
    let metrics: IslandLayoutMetrics
    let activity: (any IslandActivity)?
    let position: (index: Int, count: Int)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion || position == nil {
                Group {
                    if let activity {
                        card(activity)
                            .id(activity.id)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: CrocusMotion.seconds(CrocusMotion.C4.reducedMotionFade)), value: activity?.id)
            } else if let position {
                let cards = model.store.cardActivities
                let width = model.cardWidth
                ZStack(alignment: .topLeading) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        let isCurrent = index == position.index
                        self.card(card)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // Only the current card takes up height.
                            .frame(height: isCurrent ? nil : 0, alignment: .top)
                            .offset(x: (CGFloat(index) - model.cardStripPosition) * width)
                            .allowsHitTesting(isCurrent)
                            .accessibilityHidden(!isCurrent)
                    }
                }
            }
        }
        .onChange(of: position?.index, initial: true) { old, new in
            guard let new else { return }
            // Switched by an activity coming or going – not by a swipe, key
            // or dot, which already move the strip there.
            if old == nil || old == new || new != model.cardStripTarget {
                model.snapCards(to: new)
            }
        }
    }

    private func card(_ activity: any IslandActivity) -> some View {
        VStack(alignment: .leading, spacing: CrocusMetrics.Expanded.rowSpacing) {
            activity.expandedContent
        }
    }
}
