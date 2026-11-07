import AppKit
import SwiftUI

/// State shared between a panel and its SwiftUI content.
@MainActor
@Observable
final class OverlayPanelModel {
    var geometry: ScreenGeometry
    var showsDebugFrame = false
    /// Island frame reported by the SwiftUI view, in the panel's content
    /// coordinates (top-left origin).
    var islandFrameInWindow: CGRect?
    /// Drop/circle frame in the minimal state, same coordinates.
    var dropFrameInWindow: CGRect?

    var presentation: IslandPresentation = .idle {
        didSet {
            guard oldValue != presentation else { return }
            previousPresentation = oldValue
            expandedFromDrop = CrocusMotion.expandsFromDrop(
                from: oldValue, to: presentation, tappedDrop: dropTapPending, wasFromDrop: expandedFromDrop
            )
            dropTapPending = false
            cardsSwitched = false
            if CrocusMotion.bouncesOnArrival(from: oldValue, to: presentation, isEvent: store.currentEvent != nil, reduceMotion: CrocusMotion.reduceMotion) {
                scheduleArrivalBounce()
            }
        }
    }
    private(set) var previousPresentation: IslandPresentation = .idle
    /// The island was opened from the drop/circle: that one grows into the
    /// expanded island while the main one stays put underneath, and it
    /// collapses back into the drop. Kept through the collapse.
    private(set) var expandedFromDrop = false
    @ObservationIgnored private var dropTapPending = false

    /// Click on the drop/circle: expand its activity out of it.
    func expandFromDrop(id: String) {
        store.expand(id: id)
        // The overlay controller passes the new presentation on a moment
        // later; only remember the tap if the store really opened.
        dropTapPending = store.presentation == .expanded
    }
    /// Bumped 400 ms after an activity arrives from idle (C1): its symbol
    /// bounces once.
    private(set) var arrivalBounce = 0
    @ObservationIgnored private var arrivalBounceTask: Task<Void, Never>?

    private func scheduleArrivalBounce() {
        arrivalBounceTask?.cancel()
        arrivalBounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(CrocusMotion.seconds(CrocusMotion.C1.bounceDelay)))
            guard !Task.isCancelled else { return }
            self?.arrivalBounce += 1
        }
    }
    // MARK: - Cards (C4)

    /// Where the card strip is, as a card index – between two while a swipe
    /// moves it. Animated on the card spring when it settles.
    var cardStripPosition: CGFloat = 0
    /// The card the strip rests on or is heading to.
    @ObservationIgnored private(set) var cardStripTarget = 0
    /// A card was switched in this expanded session: the height follows the
    /// card spring from then on.
    private(set) var cardsSwitched = false

    /// One card step on the strip: the expanded island's width (each card
    /// keeps its 22 pt insets, so 44 pt lie between two cards).
    var cardWidth: CGFloat {
        switch geometry.mode {
        case .notch: CrocusMetrics.notch.expanded.width
        case .pill: CrocusMetrics.pill.expanded.width
        }
    }

    /// Fingers or mouse moved the strip `translation` points (1:1).
    func dragCards(translation: CGFloat) {
        guard presentation == .expanded, !CrocusMotion.reduceMotion, let position = store.cardPosition else { return }
        cardStripPosition = CardSwipe.position(index: position.index, count: position.count, translation: translation, width: cardWidth)
    }

    /// Released: settle on the next, previous or same card, carrying on
    /// with the fingers' speed.
    func releaseCards(translation: CGFloat, velocity: CGFloat) {
        guard presentation == .expanded, let position = store.cardPosition else { return }
        let target = CardSwipe.target(index: position.index, count: position.count, translation: translation, velocity: velocity, width: cardWidth)
        settleCards(on: target, velocity: velocity)
    }

    /// Arrow keys: one card on (+1) or back (-1).
    func stepCard(_ step: Int) {
        guard presentation == .expanded, let position = store.cardPosition else { return }
        let target = position.index + step
        guard (0..<position.count).contains(target) else { return }
        settleCards(on: target, velocity: 0)
    }

    /// A page dot.
    func showCard(at index: Int) {
        guard presentation == .expanded, let position = store.cardPosition, (0..<position.count).contains(index) else { return }
        settleCards(on: index, velocity: 0)
    }

    /// The card index changed by itself (an activity came or went): jump
    /// there without moving.
    func snapCards(to index: Int) {
        cardStripTarget = index
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { cardStripPosition = CGFloat(index) }
    }

    private func settleCards(on target: Int, velocity: CGFloat) {
        if let position = store.cardPosition, position.index != target {
            store.showCard(at: target)
            cardsSwitched = true
            AccessibilityNotification.Announcement("Activity \(target + 1) of \(position.count)").post()
        }
        cardStripTarget = target
        guard !CrocusMotion.reduceMotion else {
            snapCards(to: target)
            return
        }
        let spec = CrocusSprings.cardSwipe
        let relative = CardSwipe.relativeVelocity(velocity, width: cardWidth, from: cardStripPosition, to: CGFloat(target))
        let animation = Animation.interpolatingSpring(
            Spring(response: CrocusMotion.seconds(spec.response), dampingRatio: spec.dampingFraction),
            initialVelocity: relative / CrocusMotion.slowFactor
        )
        withAnimation(animation) { cardStripPosition = CGFloat(target) }
    }

    /// Menu bar items need the space: the right wing shrinks to 44 pt.
    var rightWingReduced = false
    /// Natural height of the expanded content, reported by `ExpandedLayout`.
    var expandedContentHeight: CGFloat?
    /// Source of the island content.
    let store: IslandStore
    /// The menu bar (and so the wallpaper under the pill) is dark.
    var menuBarIsDark = true
    /// The part of the island under the pointer (set by `MouseTracker`).
    var hoveredPart: IslandPart?
    var hoverStyle = HoverStyle.breathe

    init(geometry: ScreenGeometry, store: IslandStore) {
        self.geometry = geometry
        self.store = store
    }

    /// Horizontal centre of the island (the notch, or the screen centre in
    /// pill mode) in panel coordinates.
    var islandCenterXInPanel: CGFloat {
        geometry.islandCenterX - OverlayLayout.panelFrame(for: geometry).minX
    }

    /// Horizontal centre of the panel itself.
    var panelCenterX: CGFloat { OverlayLayout.panelSize.width / 2 }

    /// Target shape of the pill.
    var pillShapeParameters: PillShapeParameters {
        PillIslandMetrics.parameters(for: presentation, expandedContentHeight: expandedContentHeight, menuBarHeight: geometry.menuBarHeight)
    }

    /// Target shape of the notch island, `nil` in pill mode.
    var notchShapeParameters: NotchShapeParameters? {
        guard let notch = geometry.notchRect else { return nil }
        return NotchIslandMetrics.parameters(
            for: presentation,
            notch: notch.size,
            rightWingReduced: rightWingReduced,
            expandedContentHeight: expandedContentHeight
        )
    }

    /// The main island the drop hangs next to: the minimal one – also while
    /// expanded or collapsing, so the drop stays put while the island grows
    /// over it – or the compact one it merges into.
    var notchDropMainParameters: NotchShapeParameters? {
        guard let notch = geometry.notchRect else { return nil }
        return NotchIslandMetrics.parameters(
            for: presentation == .compact ? .compact : .minimal,
            notch: notch.size,
            rightWingReduced: rightWingReduced,
            expandedContentHeight: expandedContentHeight
        )
    }

    /// The drop/circle detaches or merges back (C3) – the island moves
    /// between compact and minimal, not into or out of the expanded state.
    var detachesDrop: Bool {
        CrocusMotion.C3.detaches(from: previousPresentation, to: presentation)
    }

    /// Spring for the current transition: expand into the expanded state,
    /// collapse out of it, idle → compact otherwise.
    var transitionSpring: SpringSpec {
        switch (previousPresentation, presentation) {
        // C4: after a card switch the height follows the new card.
        case (_, .expanded) where cardsSwitched: CrocusSprings.cardHeight
        case (_, .expanded): expandedFromDrop ? CrocusSprings.expandFromDrop : CrocusSprings.expand
        case (.expanded, _): CrocusSprings.collapse
        // C3: the pill shifts with the drop, on the same spring.
        case (.compact, .minimal): CrocusSprings.dropDetach
        case (.minimal, .compact): CrocusSprings.dropMerge
        default: CrocusSprings.idleToCompact
        }
    }
}

/// Borderless, transparent, non-activating panel that hosts the island on one
/// screen. It floats above the menu bar on every Space and never activates
/// Crocus; it only becomes key while `acceptsKeyboard` is on (expanded state).
final class OverlayPanel: NSPanel {
    /// Above the menu bar and its status items (`.mainMenu` = 24, `.statusBar` = 25).
    static let overlayLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)

    let displayID: CGDirectDisplayID
    let model: OverlayPanelModel
    private(set) var acceptsKeyboard = false

    /// Esc while the panel is key.
    var onEscape: (() -> Void)?
    /// ← / → while the panel is key.
    var onArrow: ((SwipeDirection) -> Void)?
    /// A recognised two-finger swipe over the island.
    var onSwipe: ((SwipeDirection) -> Void)?
    private var swipeRecognizer = SwipeRecognizer()
    private var cardTracker = CardSwipeTracker()

    init(displayID: CGDirectDisplayID, geometry: ScreenGeometry, store: IslandStore) {
        self.displayID = displayID
        self.model = OverlayPanelModel(geometry: geometry, store: store)
        let frame = OverlayLayout.panelFrame(for: geometry)
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // the pill shadow is drawn by SwiftUI (#6)
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        // The island stays when the app is hidden: Shortcuts launches Crocus
        // hidden to run an intent, and "Hide Others" (⌥⌘H) hides it too.
        canHide = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        isFloatingPanel = true
        level = Self.overlayLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        // Clicks only reach the panel while the pointer is over the island;
        // `MouseTracker` toggles this.
        ignoresMouseEvents = true
        animationBehavior = .none

        let hostingView = IslandHostingView(rootView: IslandRootView(model: model))
        hostingView.sizingOptions = []
        hostingView.onScroll = { [weak self] event in self?.handleScroll(event) }
        contentView = hostingView
        setFrame(frame, display: false)
    }

    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }

    /// Intercepts Esc and ←/→ before SwiftUI's focus handling sees them; Tab
    /// and everything else go on to the focused control.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            switch Int(event.keyCode) {
            case 53: // Esc
                onEscape?()
                return
            case 123: // ←
                onArrow?(.left)
                return
            case 124: // →
                onArrow?(.right)
                return
            default:
                break
            }
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    private func handleScroll(_ event: NSEvent) {
        let sample = ScrollSample(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            isPrecise: event.hasPreciseScrollingDeltas,
            phase: ScrollSample.Phase(event.phase),
            isMomentum: !event.momentumPhase.isEmpty,
            isDirectionInverted: event.isDirectionInvertedFromDevice,
            time: event.timestamp
        )
        // C4: sideways the cards follow the fingers. With Reduce Motion a
        // swipe just switches once it passes the threshold, as before.
        let followsFingers = !CrocusMotion.reduceMotion
        if followsFingers {
            switch cardTracker.handle(sample) {
            case .changed(let translation): model.dragCards(translation: translation)
            case .ended(let translation, let velocity): model.releaseCards(translation: translation, velocity: velocity)
            case nil: break
            }
        }
        if let direction = swipeRecognizer.handle(sample) {
            let sideways = direction == .left || direction == .right
            // The tracker owns sideways gestures – and any gesture it locked.
            if followsFingers && (sideways || cardTracker.isTracking) { return }
            onSwipe?(direction)
        }
    }

    /// Keep the panel where we put it, even over the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    /// The part of the island under a point in screen coordinates.
    func part(at point: CGPoint) -> IslandPart? {
        IslandPart.part(
            at: point,
            main: model.islandFrameInWindow.map { OverlayLayout.screenRect(forWindowRect: $0, panelFrame: frame) },
            drop: model.dropFrameInWindow.map { OverlayLayout.screenRect(forWindowRect: $0, panelFrame: frame) }
        )
    }

    /// The island's hit region in screen coordinates.
    var hitRegion: IslandHitRegion {
        IslandHitRegion(rects: [model.islandFrameInWindow, model.dropFrameInWindow].compactMap {
            $0.map { OverlayLayout.screenRect(forWindowRect: $0, panelFrame: frame) }
        })
    }

    /// Lets the panel take keyboard focus (expanded state, #7/#10) without
    /// activating Crocus, or hands focus back to the frontmost app.
    func setAcceptsKeyboard(_ accepts: Bool) {
        guard accepts != acceptsKeyboard else { return }
        acceptsKeyboard = accepts
        if accepts {
            makeKeyAndOrderFront(nil)
        } else if isKeyWindow {
            // Ordering out returns key status to the active app's window.
            orderOut(nil)
            orderFrontRegardless()
        }
    }
}

/// Hosts the island. Takes the first click although the panel is never
/// active, and hands scroll events to the swipe recognizer.
final class IslandHostingView: NSHostingView<IslandRootView> {
    var onScroll: ((NSEvent) -> Void)?

    required init(rootView: IslandRootView) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event)
    }
}

private extension ScrollSample.Phase {
    init(_ phase: NSEvent.Phase) {
        if phase.contains(.began) {
            self = .began
        } else if phase.contains(.changed) {
            self = .changed
        } else if phase.contains(.ended) {
            self = .ended
        } else if phase.contains(.cancelled) {
            self = .cancelled
        } else {
            self = .other
        }
    }
}

