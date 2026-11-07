import AppKit

/// Makes clicks pass through everywhere except over the island: while the
/// pointer is outside a panel's hit region the panel ignores mouse events.
///
/// Global mouse monitors need no Accessibility permission and work in the
/// sandbox. The global monitor sees events going to other apps, the local one
/// events going to Crocus (i.e. while the pointer is over an island).
@MainActor
final class MouseTracker {
    private var monitors: [Any] = []
    private var appObservers: [NSObjectProtocol] = []
    private let panels: () -> [OverlayPanel]
    /// Called with the pointer location (screen coordinates) on every move.
    var onPointerMove: ((CGPoint) -> Void)?

    init(panels: @escaping () -> [OverlayPanel]) {
        self.panels = panels
    }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.pointerMoved() }
            return event
        }) {
            monitors.append(local)
        }
        // Switching apps changes which monitor sees the moves; catch up at
        // once instead of waiting for the next move (#61).
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            appObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.update() }
            })
        }
        update()
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        appObservers.forEach(NotificationCenter.default.removeObserver)
        appObservers.removeAll()
    }

    private func pointerMoved() {
        update()
        onPointerMove?(NSEvent.mouseLocation)
    }

    func update() {
        let location = NSEvent.mouseLocation
        for panel in panels() {
            let isOver = panel.isVisible && panel.hitRegion.contains(location)
            if panel.ignoresMouseEvents == isOver {
                panel.ignoresMouseEvents = !isOver
            }
            let part = isOver ? panel.part(at: location) : nil
            if panel.model.hoveredPart != part {
                panel.model.hoveredPart = part
            }
        }
    }
}
