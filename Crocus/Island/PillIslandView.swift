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
        // Opened from the circle (#22): the circle grows into the expanded
        // pill; the main pill stays as it was underneath until covered.
        let fromDrop = model.expandedFromDrop
        let isExpanded = model.presentation == .expanded
        let mainStays = fromDrop && isExpanded
        let mainParameters = mainStays
            ? PillIslandMetrics.parameters(for: .minimal, expandedContentHeight: nil, menuBarHeight: model.geometry.menuBarHeight)
            : parameters
        let mainCenterX = centerX + (secondary == nil && !mainStays ? 0 : MinimalLayout.pillMainOffset)
        // The island as the user sees it: the expanded pill is centred.
        let islandFrame = mainStays ? parameters.bodyRect(centerX: centerX) : parameters.bodyRect(centerX: mainCenterX)
        let dropActivity = mainStays ? model.store.expandedContentActivity : secondary
        let dropForm: DropForm<PillShapeParameters> = fromDrop && model.presentation != .minimal
            ? .island(parameters, centerX: centerX, showsExpanded: isExpanded)
            : .drop
        // The circle and its neck always relate to the compact pill.
        let compact = CrocusMetrics.pill.compact
        let circleRect = secondary.map { _ in MinimalLayout.pillCircleRect(centerX: centerX, top: parameters.top) }

        ZStack(alignment: .topLeading) {
            mainPill(parameters: mainParameters, presentation: mainStays ? .minimal : model.presentation, centerX: mainCenterX)

            DropPresence(activity: dropActivity, detaches: model.detachesDrop, spring: model.transitionSpring) { activity in
                PillCircleView(
                    model: model, activity: activity,
                    circleRect: MinimalLayout.pillCircleRect(centerX: centerX, top: parameters.top),
                    pillRightAlone: centerX + compact.width / 2,
                    pillRightGrouped: centerX + MinimalLayout.pillMainOffset + compact.width / 2,
                    pillTop: parameters.top, pillHeight: compact.height,
                    form: dropForm
                )
            }
            // Over the pill while it detaches/merges (the neck covers its
            // outline) or grows into the expanded pill; behind it while the
            // pill expands over the circle.
            .zIndex(model.detachesDrop || fromDrop ? 1 : -1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(spring, value: parameters)
        .animation(spring, value: model.presentation)
        .animation(spring, value: mainCenterX)
        .onChange(of: islandFrame, initial: true) { _, newValue in
            model.islandFrameInWindow = newValue
        }
        .onChange(of: circleRect, initial: true) { _, newValue in
            model.dropFrameInWindow = newValue
        }
    }

    /// Fill, shadow, outline and content mask: one shape, one curve.
    private func mainPill(parameters: PillShapeParameters, presentation: IslandPresentation, centerX: CGFloat) -> some View {
        let shape = PillIslandShape(parameters: parameters, centerX: centerX)
        let panel = OverlayLayout.panelSize
        return ZStack(alignment: .topLeading) {
            PillShadow.apply(to: shape.fill(CrocusColors.island))
            content(metrics: .pill, presentation: presentation, centerX: centerX, top: parameters.top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .mask { shape }
            shape.strokeBorder(PillOutline.color(menuBarIsDark: model.menuBarIsDark), lineWidth: PillOutline.width)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .islandInteraction(
            model: model,
            shape: shape,
            anchor: UnitPoint(x: centerX / panel.width, y: parameters.top / panel.height),
            width: parameters.width
        )
    }

    /// Content at fixed positions below the pill's top edge – it never rides
    /// along with the shape (only the mask reveals or hides it).
    @ViewBuilder
    private func content(metrics: IslandLayoutMetrics, presentation: IslandPresentation, centerX: CGFloat, top: CGFloat) -> some View {
        switch presentation {
        case .idle:
            EmptyView()
        case .compact, .minimal:
            IslandCompactContent(model: model, metrics: metrics)
                .frame(width: metrics.compactWidth, height: CrocusMetrics.pill.compact.height)
                .offset(x: centerX - metrics.compactWidth / 2, y: top)
                .transition(.islandCompactContent(reduceMotion: reduceMotion, fromExpanded: model.previousPresentation == .expanded))
        case .expanded:
            IslandExpandedContent(model: model, metrics: metrics)
                .offset(x: centerX - metrics.expandedWidth / 2, y: top)
                .transition(.islandExpandedContent(reduceMotion: reduceMotion))
        }
    }
}
