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
            // Opened from the drop (#22): the drop grows into the expanded
            // island; the main one stays as it was underneath until covered.
            let fromDrop = model.expandedFromDrop
            let isExpanded = model.presentation == .expanded
            let mainStays = fromDrop && isExpanded
            let dropActivity = mainStays ? model.store.expandedContentActivity : secondary
            let dropForm: DropForm<NotchShapeParameters> = fromDrop && model.presentation != .minimal
                ? .island(parameters, centerX: centerX, showsExpanded: isExpanded)
                : .drop
            let dropMain = model.notchDropMainParameters ?? parameters
            let dropCenterX = MinimalLayout.notchDropCenterX(main: dropMain, centerX: centerX)
            let dropParameters = MinimalLayout.notchDropParameters(main: dropMain)
            let dropRect = secondary.map { _ in dropParameters.bodyRect(centerX: dropCenterX) }

            ZStack(alignment: .topLeading) {
                mainShape(
                    parameters: mainStays ? (model.notchDropMainParameters ?? parameters) : parameters,
                    presentation: mainStays ? .minimal : model.presentation,
                    metrics: metrics, centerX: centerX
                )
                // C5: the flight draws the island while it lands here.
                .opacity(model.flightIslandHidden ? 0 : 1)

                DropPresence(activity: dropActivity, detaches: model.detachesDrop, spring: model.transitionSpring) { activity in
                    NotchDropView(
                        model: model, activity: activity, centerX: dropCenterX, parameters: dropParameters,
                        mainRight: centerX + dropMain.trailing, mainHeight: dropMain.height,
                        form: dropForm, metrics: metrics
                    )
                }
                // Over the island while it detaches/merges or grows into the
                // expanded island; behind it while the island expands over it
                // (it swallows the drop).
                .zIndex(model.detachesDrop || fromDrop ? 1 : -1)
                .opacity(model.flightDropHidden ? 0 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(spring, value: parameters)
            .animation(spring, value: model.presentation)
            .onChange(of: parameters, initial: true) { _, newValue in
                model.islandFrameInWindow = newValue.bodyRect(centerX: centerX)
            }
            .onChange(of: dropRect, initial: true) { _, newValue in
                model.dropFrameInWindow = newValue
            }
        }
    }

    private func mainShape(parameters: NotchShapeParameters, presentation: IslandPresentation, metrics: IslandLayoutMetrics, centerX: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            NotchIslandShape(parameters: parameters, centerX: centerX)
                .fill(CrocusColors.island)

            Group {
                switch presentation {
                case .idle:
                    EmptyView()
                case .compact, .minimal:
                    IslandCompactContent(model: model, metrics: metrics)
                        .frame(width: parameters.width, height: parameters.height)
                        .offset(x: centerX - parameters.leading)
                        .transition(.islandCompactContent(reduceMotion: reduceMotion, fromExpanded: model.previousPresentation == .expanded))
                case .expanded:
                    IslandExpandedContent(model: model, metrics: metrics)
                        .frame(height: parameters.height, alignment: .top)
                        .offset(x: centerX - metrics.expandedWidth / 2)
                        .transition(.islandExpandedContent(reduceMotion: reduceMotion))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // Content never shows outside the (moving) shape – no silhouette
            // of the expanded panel while it collapses.
            .mask { NotchIslandShape(parameters: parameters, centerX: centerX) }
            .opacity(model.flightContentHidden ? 0 : 1)
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
