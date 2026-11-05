import SwiftUI

/// The island in pill mode: a black pill floating 6 pt below the top edge
/// with a soft shadow and a hairline outline that adapts to the wallpaper. In
/// the minimal state a 30 pt circle sits next to it and the group stays
/// centred.
struct PillIslandView: View {
    let model: OverlayPanelModel

    var body: some View {
        let parameters = model.pillShapeParameters
        let centerX = model.islandCenterXInPanel
        let spring = model.transitionSpring.animation
        let secondary = model.presentation == .minimal ? model.store.secondaryActivity : nil
        let mainCenterX = centerX + (secondary == nil ? 0 : MinimalLayout.pillMainOffset)
        let circleRect = secondary.map { _ in MinimalLayout.pillCircleRect(centerX: centerX) }

        ZStack(alignment: .top) {
            mainPill(parameters: parameters)
                .offset(x: mainCenterX - model.panelCenterX)

            if let secondary, let circleRect {
                PillCircleView(model: model, activity: secondary)
                    .offset(x: circleRect.midX - model.panelCenterX)
                    .transition(.scale(scale: 0.2, anchor: .leading).combined(with: .opacity))
            }
        }
        .padding(.top, PillIslandMetrics.topOffset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(spring, value: parameters)
        .animation(spring, value: model.presentation)
        .animation(CrocusSprings.dropDetach.animation, value: secondary?.id)
        .onChange(of: parameters.bodyRect(centerX: mainCenterX), initial: true) { _, newValue in
            model.islandFrameInWindow = newValue
        }
        .onChange(of: circleRect, initial: true) { _, newValue in
            model.dropFrameInWindow = newValue
        }
    }

    private func mainPill(parameters: PillShapeParameters) -> some View {
        let shape = RoundedRectangle(cornerRadius: parameters.cornerRadius, style: .continuous)
        return content(metrics: .pill)
            .frame(width: parameters.width, height: parameters.height, alignment: .top)
            .clipShape(shape)
            .background {
                PillShadow.apply(to: shape.fill(CrocusColors.island))
            }
            .overlay {
                shape.strokeBorder(PillOutline.color(menuBarIsDark: model.menuBarIsDark), lineWidth: PillOutline.width)
            }
            .islandInteraction(model: model, shape: shape, anchor: .top, width: parameters.width)
    }

    @ViewBuilder
    private func content(metrics: IslandLayoutMetrics) -> some View {
        switch model.presentation {
        case .idle:
            Color.clear
        case .compact, .minimal:
            IslandCompactContent(model: model, metrics: metrics)
                .frame(width: metrics.compactWidth)
                .transition(.opacity)
        case .expanded:
            IslandExpandedContent(model: model, metrics: metrics)
                .transition(.opacity)
        }
    }
}
