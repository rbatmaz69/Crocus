import SwiftUI

/// The island in notch mode: `NotchIslandShape` plus the content of the
/// current presentation, animated with the spec springs.
struct NotchIslandView: View {
    let model: OverlayPanelModel

    var body: some View {
        if let parameters = model.notchShapeParameters, let notch = model.geometry.notchRect {
            let centerX = model.islandCenterXInPanel
            let spring = model.transitionSpring.animation
            let metrics = IslandLayoutMetrics.notch(notchSize: notch.size, rightWingReduced: model.rightWingReduced)

            ZStack(alignment: .topLeading) {
                NotchIslandShape(parameters: parameters, centerX: centerX)
                    .fill(CrocusColors.island)

                Group {
                    switch model.presentation {
                    case .idle:
                        EmptyView()
                    case .compact, .minimal:
                        IslandCompactContent(model: model, metrics: metrics)
                            .frame(width: parameters.width, height: parameters.height)
                            .offset(x: centerX - parameters.leading)
                            .transition(.opacity)
                    case .expanded:
                        IslandExpandedContent(model: model, metrics: metrics)
                            .frame(height: parameters.height, alignment: .top)
                            .clipped()
                            .offset(x: centerX - metrics.expandedWidth / 2)
                            .transition(.opacity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .islandInteraction(
                model: model,
                shape: NotchIslandShape(parameters: parameters, centerX: centerX),
                anchor: UnitPoint(x: centerX / OverlayLayout.panelSize.width, y: 0)
            )
            .animation(spring, value: parameters)
            .animation(spring, value: model.presentation)
            .onChange(of: parameters, initial: true) { _, newValue in
                model.islandFrameInWindow = newValue.bodyRect(centerX: centerX)
            }
        }
    }
}

/// Picks the island for the screen's mode.
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
            case .pill: PillIslandView(model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .islandEnvironment()
    }
}
