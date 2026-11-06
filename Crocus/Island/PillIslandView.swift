import SwiftUI

/// The island in pill mode: a black pill floating 6 pt below the top edge
/// with a soft shadow and a hairline outline that adapts to the wallpaper. In
/// the minimal state a 30 pt circle sits next to it and the group stays
/// centred.
struct PillIslandView: View {
    let model: OverlayPanelModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let parameters = model.pillShapeParameters
        let centerX = model.islandCenterXInPanel
        // Reduce Motion: the shape jumps to its size (C1–C3).
        let spring: Animation? = reduceMotion ? nil : model.transitionSpring.animation
        let secondary = model.presentation == .minimal ? model.store.secondaryActivity : nil
        let mainCenterX = centerX + (secondary == nil ? 0 : MinimalLayout.pillMainOffset)
        let circleRect = secondary.map { _ in MinimalLayout.pillCircleRect(centerX: centerX) }

        ZStack(alignment: .topLeading) {
            mainPill(parameters: parameters, centerX: mainCenterX)

            if let secondary, let circleRect {
                PillCircleView(model: model, activity: secondary)
                    .offset(x: circleRect.minX, y: circleRect.minY)
                    .transition(.scale(scale: 0.2, anchor: .leading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(spring, value: parameters)
        .animation(spring, value: model.presentation)
        .animation(spring, value: mainCenterX)
        .animation(reduceMotion ? nil : CrocusSprings.dropDetach.animation, value: secondary?.id)
        .onChange(of: parameters.bodyRect(centerX: mainCenterX), initial: true) { _, newValue in
            model.islandFrameInWindow = newValue
        }
        .onChange(of: circleRect, initial: true) { _, newValue in
            model.dropFrameInWindow = newValue
        }
    }

    /// Fill, shadow, outline and content mask: one shape, one curve.
    private func mainPill(parameters: PillShapeParameters, centerX: CGFloat) -> some View {
        let shape = PillIslandShape(parameters: parameters, centerX: centerX)
        let panel = OverlayLayout.panelSize
        return ZStack(alignment: .topLeading) {
            PillShadow.apply(to: shape.fill(CrocusColors.island))
            content(metrics: .pill, centerX: centerX)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .mask { shape }
            shape.strokeBorder(PillOutline.color(menuBarIsDark: model.menuBarIsDark), lineWidth: PillOutline.width)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .islandInteraction(
            model: model,
            shape: shape,
            anchor: UnitPoint(x: centerX / panel.width, y: PillIslandMetrics.topOffset / panel.height),
            width: parameters.width
        )
    }

    /// Content at fixed positions below the pill's top edge – it never rides
    /// along with the shape (only the mask reveals or hides it).
    @ViewBuilder
    private func content(metrics: IslandLayoutMetrics, centerX: CGFloat) -> some View {
        switch model.presentation {
        case .idle:
            EmptyView()
        case .compact, .minimal:
            IslandCompactContent(model: model, metrics: metrics)
                .frame(width: metrics.compactWidth, height: CrocusMetrics.pill.compact.height)
                .offset(x: centerX - metrics.compactWidth / 2, y: PillIslandMetrics.topOffset)
                .transition(.islandCompactContent(reduceMotion: reduceMotion, fromExpanded: model.previousPresentation == .expanded))
        case .expanded:
            IslandExpandedContent(model: model, metrics: metrics)
                .offset(x: centerX - metrics.expandedWidth / 2, y: PillIslandMetrics.topOffset)
                .transition(.islandExpandedContent(reduceMotion: reduceMotion))
        }
    }
}
