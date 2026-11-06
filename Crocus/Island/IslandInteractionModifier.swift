import SwiftUI

/// Island interaction on the shape itself: click (mouse-down) to expand,
/// hover hint, click-and-drag sideways to switch cards while expanded, and
/// the context menu. Scaling is anchored at the top centre of
/// the island, so the notch shoulders and the pill's top edge stay put.
struct IslandInteractionModifier<S: Shape>: ViewModifier {
    let model: OverlayPanelModel
    let shape: S
    let anchor: UnitPoint
    /// Which shape this is; only the hovered one shows the hint.
    var part: IslandPart = .main
    /// Visible width of the shape; small shapes get a stronger hover hint.
    var width: CGFloat = 0
    /// What a click does; `nil` expands the main activity.
    var onTap: (() -> Void)?

    /// The current press already opened the island.
    @State private var opened = false
    @State private var breathPhase = false
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How hover and breathing scale settle: with the expand spring when
    /// the island opens, the hover spring otherwise; none with Reduce Motion.
    static func handOff(_ presentation: IslandPresentation, reduceMotion: Bool) -> Animation? {
        if reduceMotion { return nil }
        return presentation == .expanded ? CrocusSprings.expand.animation : CrocusSprings.hoverHint.animation
    }

    func body(content: Content) -> some View {
        let presentation = model.presentation
        let canExpand = presentation == .compact || presentation == .minimal
        let isHovered = model.hoveredPart == part
        let hoverScale = HoverHint.scale(
            style: model.hoverStyle, isHovered: isHovered, presentation: presentation, breathPhase: false, width: width
        )
        let breathes = HoverHint.breathes(style: model.hoverStyle, isHovered: isHovered, presentation: presentation)

        content
            .contentShape(shape)
            .scaleEffect(hoverScale, anchor: anchor)
            // Opening: the hint settles with the expand spring, so scale and
            // shape move as one motion (C2) instead of two springs fighting.
            .animation(Self.handOff(presentation, reduceMotion: reduceMotion), value: hoverScale)
            // Driven only by `breathPhase`, which is animated back with the hover
            // spring when the pointer leaves – so the breathing never jumps.
            .scaleEffect(HoverHint.breathFactor(breathPhase: breathPhase, width: width), anchor: anchor)
            .gesture(press, including: canExpand ? .all : .subviews)
            .simultaneousGesture(cardDrag, including: presentation == .expanded ? .all : .subviews)
            .contextMenu {
                Button("Settings…") {
                    NSApp.activate()
                    openSettings()
                }
                Button("Quit Crocus") {
                    NSApp.terminate(nil)
                }
            }
            // Opening switches the gesture off mid-press, so its end never
            // arrives – reset here, or the next click would be swallowed.
            .onChange(of: presentation) { opened = false }
            .onChange(of: breathes, initial: true) { _, breathes in
                if breathes {
                    withAnimation(.easeInOut(duration: HoverHint.breathPeriod / 2).repeatForever(autoreverses: true)) {
                        breathPhase = true
                    }
                } else {
                    withAnimation(Self.handOff(model.presentation, reduceMotion: reduceMotion)) {
                        breathPhase = false
                    }
                }
            }
    }

    /// Opens on mouse-down – no visible press: the click flows straight into
    /// the expansion (feels like part of the system). Once per press.
    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !opened else { return }
                opened = true
                if let onTap { onTap() } else { model.store.expand() }
            }
            .onEnded { _ in opened = false }
    }
}

extension IslandInteractionModifier {
    /// Click and drag sideways while expanded (mice have no two-finger
    /// swipe). A plain click stays a click: the drag needs 10 pt to start and
    /// 40 pt to switch.
    private var cardDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                guard let direction = CardDrag.direction(translation: value.translation) else { return }
                let step = CardNavigation.step(forSwipe: direction)
                if step > 0 { model.store.showNextCard() } else if step < 0 { model.store.showPreviousCard() }
            }
    }
}

extension View {
    func islandInteraction(
        model: OverlayPanelModel,
        shape: some Shape,
        anchor: UnitPoint,
        part: IslandPart = .main,
        width: CGFloat,
        onTap: (() -> Void)? = nil
    ) -> some View {
        modifier(IslandInteractionModifier(model: model, shape: shape, anchor: anchor, part: part, width: width, onTap: onTap))
    }
}
