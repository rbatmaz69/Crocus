import AppKit

/// Watches mouse-down events anywhere while the island is expanded, so a
/// click next to it collapses the island. The monitors only observe: the
/// click still reaches the app below.
@MainActor
final class ClickOutsideMonitor {
    private var monitors: [Any] = []

    var isRunning: Bool { !monitors.isEmpty }

    func start(onClick: @escaping (CGPoint) -> Void) {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { _ in
            MainActor.assumeIsolated { onClick(NSEvent.mouseLocation) }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            MainActor.assumeIsolated { onClick(NSEvent.mouseLocation) }
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }
}
