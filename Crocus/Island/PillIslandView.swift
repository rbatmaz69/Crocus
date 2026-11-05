import SwiftUI

/// The island in pill mode: a black pill floating 6 pt below the top edge
/// with a soft shadow and a hairline outline that adapts to the wallpaper.
struct PillIslandView: View {
    let model: OverlayPanelModel

    var body: some View {
        let parameters = model.pillShapeParameters
        let centerX = model.islandCenterXInPanel
        let spring = model.transitionSpring.animation
        let metrics = IslandLayoutMetrics.pill
        let shape = RoundedRectangle(cornerRadius: parameters.cornerRadius, style: .continuous)

        content(metrics: metrics)
            .frame(width: parameters.width, height: parameters.height, alignment: .top)
            .clipShape(shape)
            .background {
                shadowed(shape.fill(CrocusColors.island))
            }
            .overlay {
                shape.strokeBorder(PillOutline.color(menuBarIsDark: model.menuBarIsDark), lineWidth: PillOutline.width)
            }
            .islandInteraction(model: model, shape: shape, anchor: .top)
            .offset(x: centerX - model.panelCenterX)
            .padding(.top, PillIslandMetrics.topOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(spring, value: parameters)
            .animation(spring, value: model.presentation)
            .onChange(of: parameters, initial: true) { _, newValue in
                model.islandFrameInWindow = newValue.bodyRect(centerX: centerX)
            }
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

    /// Applies the pill shadows from the spec (CSS blur → SwiftUI radius = blur / 2).
    private func shadowed(_ view: some View) -> some View {
        CrocusMetrics.pill.shadows.reduce(AnyView(view)) { view, shadow in
            AnyView(view.shadow(color: .black.opacity(shadow.opacity), radius: shadow.radius, x: 0, y: shadow.y))
        }
    }
}
