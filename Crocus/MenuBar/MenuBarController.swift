import AppKit
import SwiftUI

/// The crocus in the menu bar and its panel (#61). An `NSPopover` instead of
/// `MenuBarExtra`: it sits centred under the icon with an arrow pointing at
/// it, opens and closes with the system's own animation and Tahoe's glass,
/// and closes when clicking anywhere else.
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private unowned let app: AppDelegate
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var hosting: NSHostingController<MenuBarPanel>?
    /// Whether closing hands focus back to the previous app (see `close`).
    private var returnsFocus = true
    /// The event that started the panel's closing. A click on the icon
    /// while it is open first closes it (transient popover, on mouse-down)
    /// and then reaches `toggle` – which must not open it again (it
    /// flickered). Any other click acts normally.
    private var closingEventTime: TimeInterval?
    /// Closing animation running; a click meanwhile opens it again after.
    private var isClosing = false
    private var reopensAfterClosing = false

    init(app: AppDelegate) {
        self.app = app
        super.init()
    }

    func start() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(toggle(_:))
        // Like a menu: opens on mouse-down.
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        statusItem = item

        popover.behavior = .transient
        // The system's own open/close animation (macOS design language).
        popover.animates = true
        popover.delegate = self
        let hosting = NSHostingController(rootView: MenuBarPanel(app: app, menuBar: self))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        self.hosting = hosting
        // Built once up front, so the first open doesn't lay it out mid-animation.
        hosting.view.layoutSubtreeIfNeeded()

        updateIcon()
    }

    func stop() {
        popover.close()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
    }

    var isShown: Bool { popover.isShown }

    @objc private func toggle(_ sender: Any?) {
        // This very click just closed it: leave it closed.
        if let time = NSApp.currentEvent?.timestamp, time == closingEventTime { return }
        if isClosing {
            reopensAfterClosing = true
        } else if popover.isShown {
            close()
        } else {
            show()
        }
    }

    func show() {
        guard let button = statusItem?.button else { return }
        // The final size before it shows: the grow animation then runs
        // once, without the layout resizing it on the way (smooth opening).
        if let view = hosting?.view {
            view.layoutSubtreeIfNeeded()
            popover.contentSize = view.fittingSize
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Then in front, so the panel takes the keyboard (Tab, Esc, ⌘, and
        // ⌘Q) – after the animation started, not before it. Also the icon's
        // highlight: set during the click, the button's own mouse-up would
        // take it away again (it flickered); a turn later it stays.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.popover.isShown, let window = self.popover.contentViewController?.view.window else { return }
            button.highlight(true)
            NSApp.activate()
            window.makeKey()
            // Mouse moves reach `MouseTracker` while the panel is open, so
            // the island still notices the pointer.
            window.acceptsMouseMovedEvents = true
        }
    }

    /// Closes the panel. Focus goes back to the previous app unless the
    /// action opens a Crocus window (Settings, onboarding, a system prompt):
    /// while Crocus stays active without a window, the island gets no mouse
    /// moves.
    func close(returningFocus: Bool = true) {
        returnsFocus = returningFocus
        popover.performClose(nil)
    }

    // MARK: NSPopoverDelegate

    func popoverWillClose(_ notification: Notification) {
        isClosing = true
        closingEventTime = NSApp.currentEvent?.timestamp
    }

    func popoverDidClose(_ notification: Notification) {
        isClosing = false
        if reopensAfterClosing {
            reopensAfterClosing = false
            returnsFocus = true
            statusItem?.button?.highlight(false)
            show()
            return
        }
        statusItem?.button?.highlight(false)
        let returns = returnsFocus
        returnsFocus = true
        guard returns else { return }
        // A turn later, once any window the action opened is up.
        Task { @MainActor [weak self] in self?.app.returnFocus() }
    }

    // MARK: Icon

    /// The template crocus; with a dot while a permission is missing. Follows
    /// the permissions as they change.
    private func updateIcon() {
        let needsAttention = withObservationTracking {
            !app.menuBarAttention.isEmpty
        } onChange: {
            Task { @MainActor [weak self] in self?.updateIcon() }
        }
        guard let button = statusItem?.button else { return }
        let image = NSImage(named: needsAttention ? "MenuBarIconBadge" : "MenuBarIcon")
        image?.isTemplate = true
        button.image = image
        button.setAccessibilityLabel(needsAttention ? "Crocus, needs your permission" : "Crocus")
        button.toolTip = "Crocus"
    }
}
