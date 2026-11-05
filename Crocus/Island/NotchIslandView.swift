import SwiftUI

/// The island in notch mode: `NotchIslandShape` plus the content of the
/// current presentation, animated with the spec springs.
struct NotchIslandView: View {
    let model: OverlayPanelModel

    var body: some View {
        if let parameters = model.notchShapeParameters, let notch = model.geometry.notchRect {
            let centerX = model.notchCenterXInPanel
            let spring = model.transitionSpring.animation

            ZStack(alignment: .topLeading) {
                NotchIslandShape(parameters: parameters, centerX: centerX)
                    .fill(CrocusColors.island)

                Group {
                    switch model.presentation {
                    case .idle:
                        EmptyView()
                    case .compact:
                        compact(notch: notch.size)
                            .frame(width: parameters.width, height: parameters.height)
                            .offset(x: centerX - parameters.leading)
                            .transition(.opacity)
                    case .expanded:
                        expanded(notch: notch.size)
                            .frame(height: parameters.height, alignment: .top)
                            .clipped()
                            .offset(x: centerX - CrocusMetrics.notch.expanded.width / 2)
                            .transition(.opacity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(spring, value: parameters)
            .animation(spring, value: model.presentation)
            .onChange(of: parameters, initial: true) { _, newValue in
                model.islandFrameInWindow = newValue.bodyRect(centerX: centerX)
            }
        }
    }

    @ViewBuilder
    private func compact(notch: CGSize) -> some View {
        let rightWing = model.rightWingReduced ? CrocusMetrics.Compact.reducedWingWidth : CrocusMetrics.notch.wingWidth
        #if DEBUG
        CompactLayout(notchWidth: notch.width, rightWingWidth: rightWing) {
            DebugIslandSamples.compactLeading
        } trailing: {
            DebugIslandSamples.compactTrailing(reduced: model.rightWingReduced)
        }
        #else
        CompactLayout(notchWidth: notch.width, rightWingWidth: rightWing) {
            EmptyView()
        } trailing: {
            EmptyView()
        }
        #endif
    }

    @ViewBuilder
    private func expanded(notch: CGSize) -> some View {
        #if DEBUG
        ExpandedLayout(notchSize: notch) { model.expandedContentHeight = $0 } source: {
            Text("build.sh · Terminal")
        } status: {
            Text("2:14 ago")
        } content: {
            DebugIslandSamples.expandedContent(large: model.usesLargeSample)
        }
        #else
        EmptyView()
        #endif
    }
}

/// Picks the island for the screen's mode. Pill mode keeps the placeholder
/// until #6.
struct IslandRootView: View {
    let model: OverlayPanelModel

    var body: some View {
        ZStack(alignment: .top) {
            if model.showsDebugFrame {
                Rectangle()
                    .fill(Color.red.opacity(0.06))
                    .strokeBorder(Color.red.opacity(0.6), lineWidth: 1)
            }

            switch model.geometry.mode {
            case .notch: NotchIslandView(model: model)
            case .pill: IslandPlaceholderView(model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .islandEnvironment()
    }
}
