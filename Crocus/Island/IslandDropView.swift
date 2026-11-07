import SwiftUI

/// What the drop/circle view is drawing (#22).
enum DropForm<Parameters: Equatable>: Equatable {
    /// The drop at rest next to the island – or detaching / merging (C3).
    case drop
    /// Grown into the island (opened from the drop): the island's shape at
    /// `centerX`, with the expanded content while open.
    case island(Parameters, centerX: CGFloat, showsExpanded: Bool)
}

/// The second activity in the minimal state, as a drop hanging from the top
/// edge next to the notch island. Reuses `NotchIslandShape`, so it gets the
/// same concave shoulders. Click expands this activity out of the drop: the
/// drop grows into the expanded island. Detaches and merges back as in
/// storyboard C3 (`CrocusMotion.C3`).
struct NotchDropView: View {
    let model: OverlayPanelModel
    let activity: any IslandActivity
    /// Horizontal centre of the drop at rest, in panel coordinates.
    let centerX: CGFloat
    let parameters: NotchShapeParameters
    /// Right edge and height of the main island – where the neck grows from.
    let mainRight: CGFloat
    let mainHeight: CGFloat
    var form: DropForm<NotchShapeParameters> = .drop
    let metrics: IslandLayoutMetrics
    @Environment(\.dropDetachProgress) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias C3 = CrocusMotion.C3

    var body: some View {
        let shape: NotchIslandShape = switch form {
        case .drop: NotchIslandShape(parameters: parameters, centerX: centerX)
        case .island(let island, let islandCenterX, _): NotchIslandShape(parameters: island, centerX: islandCenterX)
        }
        let size = CrocusMetrics.dropContentSize
        let offsetX = C3.offset(progress: progress, travel: MinimalLayout.spacing + parameters.width)
        let scale = C3.scale(progress: progress)
        let isDrop = form == .drop

        ZStack(alignment: .topLeading) {
            if isDrop && C3.isGooey(progress: progress) {
                GooeyDrop(bridge: CGRect(x: mainRight - C3.bridgeWidth, y: 0, width: C3.bridgeWidth, height: mainHeight)) { rect in
                    shape.path(in: rect).applying(C3.transform(anchor: CGPoint(x: centerX, y: 0), offsetX: offsetX, scale: scale))
                }
            } else {
                shape.fill(CrocusColors.island).offset(x: offsetX)
            }
            Group {
                switch form {
                case .drop:
                    activity.minimal
                        .frame(width: size, height: size)
                        .position(x: centerX + offsetX, y: parameters.height / 2)
                        .opacity(C3.contentOpacity(progress: progress))
                        .transition(.islandDropContent(reduceMotion: reduceMotion))
                case .island(let island, let islandCenterX, true):
                    IslandExpandedContent(model: model, metrics: metrics)
                        .frame(height: island.height, alignment: .top)
                        .offset(x: islandCenterX - metrics.expandedWidth / 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .transition(.islandExpandedFromDrop(
                            anchor: UnitPoint(x: islandCenterX / OverlayLayout.panelSize.width, y: 0),
                            reduceMotion: reduceMotion
                        ))
                case .island:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .mask { shape.offset(x: offsetX) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .islandInteraction(
            model: model,
            shape: shape,
            anchor: UnitPoint(x: shape.centerX / OverlayLayout.panelSize.width, y: 0),
            part: isDrop ? .drop : .main,
            width: shape.parameters.width,
            onTap: isDrop ? { model.expandFromDrop(id: activity.id) } : nil
        )
        .modifier(DropAccessibility(isDrop: isDrop, label: activity.accessibilityLabel, expand: { model.expandFromDrop(id: activity.id) }))
    }
}

/// The second activity in pill mode: a circle next to the pill with its own
/// shadow and outline, in panel coordinates. Detaches from the pill's right
/// end (which moves left on the same spring to keep the group centred) and
/// merges back (C3). Shadow and outline come in with its content. Click
/// expands it out of the circle: the circle grows into the expanded pill.
struct PillCircleView: View {
    let model: OverlayPanelModel
    let activity: any IslandActivity
    /// The circle at rest, in panel coordinates.
    let circleRect: CGRect
    /// The pill's right edge alone (compact) and next to the circle (minimal).
    let pillRightAlone: CGFloat
    let pillRightGrouped: CGFloat
    let pillTop: CGFloat
    let pillHeight: CGFloat
    var form: DropForm<PillShapeParameters> = .drop
    @Environment(\.dropDetachProgress) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias C3 = CrocusMotion.C3

    var body: some View {
        let diameter = circleRect.width
        let size = CrocusMetrics.circleContentSize
        // Starts inside the pill's right end (where that end is at progress 0).
        let travel = circleRect.midX - (pillRightAlone - diameter / 2)
        let offsetX = C3.offset(progress: progress, travel: travel)
        let scale = C3.scale(progress: progress)
        let pillRight = pillRightAlone + (pillRightGrouped - pillRightAlone) * progress
        let isDrop = form == .drop
        // A pill with width = height is the circle – so it can grow into the
        // expanded pill on the same shape.
        let shape: PillIslandShape = switch form {
        case .drop:
            PillIslandShape(
                parameters: PillShapeParameters(width: diameter, height: diameter, cornerRadius: diameter / 2, top: circleRect.minY),
                centerX: circleRect.midX
            )
        case .island(let island, let islandCenterX, _): PillIslandShape(parameters: island, centerX: islandCenterX)
        }
        let detail = C3.contentOpacity(progress: progress)
        let metrics = IslandLayoutMetrics.pill

        ZStack(alignment: .topLeading) {
            if isDrop && C3.isGooey(progress: progress) {
                GooeyDrop(bridge: CGRect(x: pillRight - C3.bridgeWidth, y: pillTop, width: C3.bridgeWidth, height: pillHeight)) { rect in
                    shape.path(in: rect).applying(C3.transform(anchor: CGPoint(x: circleRect.midX, y: circleRect.midY), offsetX: offsetX, scale: scale))
                }
            } else {
                // Shadow fades in with the content; the fill itself is solid.
                PillShadow.apply(to: shape.fill(CrocusColors.island))
                    .opacity(detail)
                    .offset(x: offsetX)
                shape.fill(CrocusColors.island)
                    .offset(x: offsetX)
            }
            Group {
                switch form {
                case .drop:
                    activity.minimal
                        .frame(width: CrocusMetrics.dropContentSize, height: CrocusMetrics.dropContentSize)
                        .scaleEffect(size / CrocusMetrics.dropContentSize)
                        .position(x: circleRect.midX + offsetX, y: circleRect.midY)
                        .opacity(detail)
                        .transition(.islandDropContent(reduceMotion: reduceMotion))
                case .island(let island, let islandCenterX, true):
                    IslandExpandedContent(model: model, metrics: metrics)
                        .offset(x: islandCenterX - metrics.expandedWidth / 2, y: island.top)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .transition(.islandExpandedFromDrop(
                            anchor: UnitPoint(x: islandCenterX / OverlayLayout.panelSize.width, y: island.top / OverlayLayout.panelSize.height),
                            reduceMotion: reduceMotion
                        ))
                case .island:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .mask { shape.offset(x: offsetX) }
            if !(isDrop && C3.isGooey(progress: progress)) {
                shape.strokeBorder(PillOutline.color(menuBarIsDark: model.menuBarIsDark), lineWidth: PillOutline.width)
                    .offset(x: offsetX)
                    .opacity(detail)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .islandInteraction(
            model: model, shape: shape,
            anchor: UnitPoint(x: shape.centerX / OverlayLayout.panelSize.width, y: shape.parameters.top / OverlayLayout.panelSize.height),
            part: isDrop ? .drop : .main, width: shape.parameters.width,
            onTap: isDrop ? { model.expandFromDrop(id: activity.id) } : nil
        )
        .modifier(DropAccessibility(isDrop: isDrop, label: activity.accessibilityLabel, expand: { model.expandFromDrop(id: activity.id) }))
    }
}

/// At rest, the drop is one button labelled with its activity; grown into
/// the island, its expanded content speaks for itself. No `if`/`else`: that
/// would give the view a new identity and break its shape animation.
private struct DropAccessibility: ViewModifier {
    let isDrop: Bool
    let label: String
    let expand: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: isDrop ? .ignore : .contain)
            .accessibilityLabel(isDrop ? label : "")
            .accessibilityHint(isDrop ? "Press to expand" : "")
            .accessibilityAddTraits(isDrop ? .isButton : [])
            .accessibilityAction { if isDrop { expand() } }
    }
}

extension AnyTransition {
    /// Expanded content opened from the drop: in its place, like from the
    /// main island (C2: 0.9× → 1, blur, fade), but a little later – the
    /// shape travels from the drop first, so the content never shows ahead
    /// of it, nor does it fly in from the side. Collapsing: as C2.
    static func islandExpandedFromDrop(anchor: UnitPoint, reduceMotion: Bool) -> AnyTransition {
        typealias C2 = CrocusMotion.C2
        if reduceMotion {
            return .opacity.animation(.easeInOut(duration: CrocusMotion.seconds(C2.reducedMotionFade)))
        }
        let hidden = IslandContentEntrance(opacity: 0, blur: C2.blur, scale: C2.expandedInScale, anchor: anchor)
        let identity = IslandContentEntrance(opacity: 1, blur: 0, scale: 1, anchor: anchor)
        return .asymmetric(
            insertion: AnyTransition.modifier(active: hidden, identity: identity)
                .animation(CrocusSprings.expandFromDrop.animation.delay(CrocusMotion.seconds(C2.fromDropContentDelay))),
            removal: AnyTransition.modifier(active: hidden, identity: identity).animation(CrocusSprings.collapse.animation)
        )
    }

    /// The drop's own symbol when it grows into the island: dissolves with
    /// the expand-from-drop spring, comes back with the collapse spring.
    static func islandDropContent(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity.animation(.easeInOut(duration: CrocusMotion.seconds(CrocusMotion.C2.reducedMotionFade)))
        }
        return .asymmetric(
            insertion: .opacity.animation(CrocusSprings.collapse.animation),
            removal: .opacity.animation(CrocusSprings.expandFromDrop.animation)
        )
    }
}

/// Shows the second activity's drop/circle. Between compact and minimal it
/// runs C3: grows out of the island and detaches, or flows back in. When the
/// island expands it stays at rest behind the island until it is covered (the
/// island swallows it); collapsing, the shrinking island uncovers it. The
/// values are computed per frame from the springs – an animatable transition
/// modifier did not interpolate them (the drop just appeared). Reduce
/// Motion: 200 ms fade at the final position.
struct DropPresence<Content: View>: View {
    let activity: (any IslandActivity)?
    /// The island moves between compact and minimal (C3), not expanding or
    /// collapsing.
    let detaches: Bool
    /// The island's spring for this change; the drop stays until it settles.
    let spring: SpringSpec
    @ViewBuilder let content: (any IslandActivity) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: Equatable {
        case detaching, merging
        /// Behind the expanding island, until it covers the drop.
        case covered(SpringSpec)

        var leaves: Bool { self != .detaching }
    }

    /// The last activity shown – still drawn while it leaves.
    @State private var last: (any IslandActivity)?
    @State private var phase: Phase?
    /// Start of the running phase.
    @State private var start: Date?

    private typealias C3 = CrocusMotion.C3

    var body: some View {
        Group {
            if reduceMotion {
                ZStack {
                    if let activity {
                        content(activity)
                            .transition(.opacity.animation(.easeInOut(duration: CrocusMotion.seconds(C3.reducedMotionFade))))
                    }
                }
            } else {
                TimelineView(.animation(paused: phase == nil)) { context in
                    if let shown = activity ?? (phase?.leaves == true ? last : nil) {
                        content(shown).environment(\.dropDetachProgress, progress(at: context.date, showing: shown.id))
                    }
                }
            }
        }
        .onChange(of: activity?.id, initial: true) { old, new in
            if let activity { last = activity }
            guard !reduceMotion, (old == nil) != (new == nil) else { return }
            let appears = new != nil
            // Uncovered by the collapsing island: simply there, at rest.
            guard detaches || !appears else { return }
            let next: Phase = detaches ? (appears ? .detaching : .merging) : .covered(spring)
            let now = Date()
            phase = next
            start = now
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(CrocusMotion.seconds(duration(of: next))))
                guard start == now else { return }
                phase = nil
                start = nil
            }
        }
    }

    private func duration(of phase: Phase) -> Double {
        switch phase {
        case .detaching: C3.duration(detaching: true)
        case .merging: C3.duration(detaching: false)
        case .covered(let spec): spec.spring.settlingDuration
        }
    }

    private func progress(at date: Date, showing id: String) -> CGFloat {
        // Inserted, but `onChange` has not started the detach yet: still a bud.
        guard let phase, let start else { return last?.id == id || !detaches ? 1 : 0 }
        let elapsed = date.timeIntervalSince(start) / CrocusMotion.slowFactor
        switch phase {
        case .detaching: return C3.progress(detaching: true, elapsed: elapsed)
        case .merging: return C3.progress(detaching: false, elapsed: elapsed)
        case .covered: return 1
        }
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


