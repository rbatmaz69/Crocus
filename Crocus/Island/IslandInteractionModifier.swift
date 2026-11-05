import SwiftUI

/// Island interaction on the shape itself: click to expand, press feedback,
/// hover hint, click-and-drag sideways to switch cards while expanded, and
/// the context menu. Scaling is anchored at the top centre of
/// the island, so the notch shoulders and the pill's top edge stay put.
struct IslandInteractionModifier<S: Shape>: ViewModifier {
    let model: OverlayPanelModel
    let shape: S
    let anchor: UnitPoint
    /// Which shape this is; only the hovered one shows the hint.
    var part: IslandPart = .main
    /// What a click does; `nil` expands the main activity.
    var onTap: (() -> Void)?

    @State private var isPressed = false
    @State private var pressStarted: Date?
    @State private var breathPhase = false
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        let presentation = model.presentation
        let canExpand = presentation == .compact || presentation == .minimal
        let isHovered = model.hoveredPart == part
        let hoverScale = HoverHint.scale(
            style: model.hoverStyle, isHovered: isHovered, presentation: presentation, breathPhase: false
        )
        let breathes = HoverHint.breathes(style: model.hoverStyle, isHovered: isHovered, presentation: presentation)

        content
            .contentShape(shape)
            .scaleEffect(isPressed ? HoverHint.pressedScale : 1, anchor: anchor)
            .scaleEffect(hoverScale, anchor: anchor)
            .animation(CrocusSprings.hoverHint.animation, value: hoverScale)
            // Driven only by `breathPhase`, which is animated back with the hover
            // spring when the pointer leaves – so the breathing never jumps.
            .scaleEffect(HoverHint.breathFactor(breathPhase: breathPhase), anchor: anchor)
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
            .onChange(of: breathes, initial: true) { _, breathes in
                if breathes {
                    withAnimation(.easeInOut(duration: HoverHint.breathPeriod / 2).repeatForever(autoreverses: true)) {
                        breathPhase = true
                    }
                } else {
                    withAnimation(CrocusSprings.hoverHint.animation) {
                        breathPhase = false
                    }
                }
            }
    }

    /// Press feedback plus click: 0.98× while pressed (at least 80 ms), expand
    /// on release.
    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressed else { return }
                pressStarted = .now
                withAnimation(.easeOut(duration: 0.06)) { isPressed = true }
            }
            .onEnded { _ in
                let elapsed = pressStarted.map { Date.now.timeIntervalSince($0) } ?? HoverHint.minimumPressDuration
                let remaining = max(HoverHint.minimumPressDuration - elapsed, 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
                    withAnimation(CrocusSprings.hoverHint.animation) { isPressed = false }
                }
                if let onTap { onTap() } else { model.store.expand() }
            }
    }
}

extension IslandInteractionModifier {
    /// Click and drag sideways while expanded (mice have no two-finger
    /// swipe). A plain click stays a click: the drag needs 10 pt to start and
    /// 40 pt to switch.
    private var cardDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                switch CardDrag.direction(translation: value.translation) {
                case .left: model.store.showNextCard()
                case .right: model.store.showPreviousCard()
                default: break
                }
            }
    }
}

extension View {
    func islandInteraction(
        model: OverlayPanelModel,
        shape: some Shape,
        anchor: UnitPoint,
        part: IslandPart = .main,
        onTap: (() -> Void)? = nil
    ) -> some View {
        modifier(IslandInteractionModifier(model: model, shape: shape, anchor: anchor, part: part, onTap: onTap))
    }
}
