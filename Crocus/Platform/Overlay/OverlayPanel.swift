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
            if oldValue != presentation { previousPresentation = oldValue }
        }
    }
    private(set) var previousPresentation: IslandPresentation = .idle
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
        PillIslandMetrics.parameters(for: presentation, expandedContentHeight: expandedContentHeight)
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

    /// Spring for the current transition: expand into the expanded state,
    /// collapse out of it, idle → compact otherwise.
    var transitionSpring: SpringSpec {
        switch (previousPresentation, presentation) {
        case (_, .expanded): CrocusSprings.expand
        case (.expanded, _): CrocusSprings.collapse
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
            isDirectionInverted: event.isDirectionInvertedFromDevice
        )
        if let direction = swipeRecognizer.handle(sample) {
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
