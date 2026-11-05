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

        let hostingView = NSHostingView(rootView: IslandRootView(model: model))
        hostingView.sizingOptions = []
        contentView = hostingView
        setFrame(frame, display: false)
    }

    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }

    /// Keep the panel where we put it, even over the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    /// The island's hit region in screen coordinates.
    var hitRegion: IslandHitRegion {
        IslandHitRegion(rect: model.islandFrameInWindow.map {
            OverlayLayout.screenRect(forWindowRect: $0, panelFrame: frame)
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
