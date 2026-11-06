import SwiftUI

/// The island in notch mode: `NotchIslandShape` plus the content of the
/// current presentation, animated with the spec springs; in the minimal state
/// the second activity hangs next to it as a drop.
struct NotchIslandView: View {
    let model: OverlayPanelModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let parameters = model.notchShapeParameters, let notch = model.geometry.notchRect {
            let centerX = model.islandCenterXInPanel
            // Reduce Motion: the shape jumps to its size (C1–C3).
            let spring: Animation? = reduceMotion ? nil : model.transitionSpring.animation
            let metrics = IslandLayoutMetrics.notch(notchSize: notch.size, rightWingReduced: model.rightWingReduced)
            let secondary = model.presentation == .minimal ? model.store.secondaryActivity : nil
            let dropCenterX = MinimalLayout.notchDropCenterX(main: parameters, centerX: centerX)
            let dropParameters = MinimalLayout.notchDropParameters(main: parameters)
            let dropRect = secondary.map { _ in dropParameters.bodyRect(centerX: dropCenterX) }

            ZStack(alignment: .topLeading) {
                mainShape(parameters: parameters, metrics: metrics, centerX: centerX)

                if let secondary {
                    NotchDropView(model: model, activity: secondary, centerX: dropCenterX, parameters: dropParameters)
                        .transition(
                            .scale(scale: 0.2, anchor: UnitPoint(x: (dropCenterX - dropParameters.leading) / OverlayLayout.panelSize.width, y: 0))
                                .combined(with: .opacity)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(spring, value: parameters)
            .animation(spring, value: model.presentation)
            .animation(reduceMotion ? nil : CrocusSprings.dropDetach.animation, value: secondary?.id)
            .onChange(of: parameters, initial: true) { _, newValue in
                model.islandFrameInWindow = newValue.bodyRect(centerX: centerX)
            }
            .onChange(of: dropRect, initial: true) { _, newValue in
                model.dropFrameInWindow = newValue
            }
        }
    }

    private func mainShape(parameters: NotchShapeParameters, metrics: IslandLayoutMetrics, centerX: CGFloat) -> some View {
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
                        .transition(.islandCompactContent(reduceMotion: reduceMotion))
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
            anchor: UnitPoint(x: centerX / OverlayLayout.panelSize.width, y: 0),
            width: parameters.width
        )
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
