import SwiftUI

/// The second activity in the minimal state, as a drop hanging from the top
/// edge next to the notch island. Reuses `NotchIslandShape`, so it gets the
/// same concave shoulders. Click expands this activity.
struct NotchDropView: View {
    let model: OverlayPanelModel
    let activity: any IslandActivity
    /// Horizontal centre of the drop in panel coordinates.
    let centerX: CGFloat
    let parameters: NotchShapeParameters

    var body: some View {
        let shape = NotchIslandShape(parameters: parameters, centerX: centerX)
        let size = CrocusMetrics.dropContentSize

        ZStack(alignment: .topLeading) {
            shape.fill(CrocusColors.island)
            activity.minimal
                .frame(width: size, height: size)
                .position(x: centerX, y: parameters.height / 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .islandInteraction(
            model: model,
            shape: shape,
            anchor: UnitPoint(x: centerX / OverlayLayout.panelSize.width, y: 0),
            part: .drop,
            width: parameters.width,
            onTap: { model.store.expand(id: activity.id) }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(activity.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }
}

/// The second activity in pill mode: a 30 pt circle with its own shadow and
/// outline. Click expands this activity.
struct PillCircleView: View {
    let model: OverlayPanelModel
    let activity: any IslandActivity

    var body: some View {
        let diameter = MinimalLayout.pillCircleDiameter
        let size = CrocusMetrics.circleContentSize

        activity.minimal
            .frame(width: CrocusMetrics.dropContentSize, height: CrocusMetrics.dropContentSize)
            .scaleEffect(size / CrocusMetrics.dropContentSize)
            .frame(width: diameter, height: diameter)
            .background {
                PillShadow.apply(to: Circle().fill(CrocusColors.island))
            }
            .overlay {
                Circle().strokeBorder(PillOutline.color(menuBarIsDark: model.menuBarIsDark), lineWidth: PillOutline.width)
            }
            .islandInteraction(
                model: model, shape: Circle(), anchor: .top, part: .drop, width: diameter,
                onTap: { model.store.expand(id: activity.id) }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(activity.accessibilityLabel)
            .accessibilityAddTraits(.isButton)
    }
}

/// The pill shadows from the spec (CSS blur → SwiftUI radius = blur / 2).
enum PillShadow {
    static func apply(to view: some View) -> some View {
        CrocusMetrics.pill.shadows.reduce(AnyView(view)) { view, shadow in
            AnyView(view.shadow(color: .black.opacity(shadow.opacity), radius: shadow.radius, x: 0, y: shadow.y))
        }
    }
}
