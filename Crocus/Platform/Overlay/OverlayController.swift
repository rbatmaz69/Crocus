import AppKit
import os

/// Owns one `OverlayPanel` per connected screen, keeps them in sync with the
/// screen configuration and hides them during full-screen videos.
@MainActor
@Observable
final class OverlayController {
    /// Debug aid: draw the panel bounds.
    var showsDebugFrame = false {
        didSet { panels.values.forEach { $0.model.showsDebugFrame = showsDebugFrame } }
    }

    /// Debug aid until the expanded state exists: let the panel under the
    /// pointer take keyboard focus.
    var acceptsKeyboard = false {
        didSet { applyKeyboardFocus() }
    }

    @ObservationIgnored private var panels: [CGDirectDisplayID: OverlayPanel] = [:]
    @ObservationIgnored private lazy var mouseTracker = MouseTracker { [unowned self] in Array(self.panels.values) }
    @ObservationIgnored private let detector = FullScreenVideoDetector()
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var fullScreenTimer: Timer?
    @ObservationIgnored private let defaults: UserDefaults

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Overlay")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var panelCount: Int { panels.count }

    func start() {
        AppSettings.registerDefaults(in: defaults)
        let powerState = SystemPowerAssertions().isDisplaySleepPrevented().map { "\($0)" } ?? "unreadable"
        Self.logger.info("Display sleep assertion state: \(powerState, privacy: .public)")
        reconcile()
        mouseTracker.start()

        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) {
            $0.reconcile()
        }
        observe(NotificationCenter.default, UserDefaults.didChangeNotification) {
            $0.updateVisibility()
        }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { $0.updateVisibility() }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { $0.updateVisibility() }
    }

    func stop() {
        for (center, token) in observers {
            center.removeObserver(token)
        }
        observers.removeAll()
        fullScreenTimer?.invalidate()
        fullScreenTimer = nil
        mouseTracker.stop()
        panels.values.forEach { $0.close() }
        panels.removeAll()
    }

    /// Creates panels for new screens, closes panels of removed screens and
    /// repositions the rest.
    func reconcile() {
        var seen = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            seen.insert(displayID)
            let frame = OverlayLayout.panelFrame(for: screen.frame)
            let hasNotch = screen.safeAreaInsets.top > 0

            if let panel = panels[displayID] {
                panel.model.hasNotch = hasNotch
                if panel.frame != frame {
                    panel.setFrame(frame, display: true)
                }
            } else {
                let panel = OverlayPanel(displayID: displayID, frame: frame, hasNotch: hasNotch)
                panel.model.showsDebugFrame = showsDebugFrame
                panels[displayID] = panel
                panel.orderFrontRegardless()
                Self.logger.info("Added overlay for display \(displayID) (\(hasNotch ? "notch" : "pill", privacy: .public))")
            }
        }

        for (displayID, panel) in panels where !seen.contains(displayID) {
            panel.close()
            panels[displayID] = nil
            Self.logger.info("Removed overlay for display \(displayID)")
        }

        updateVisibility()
        mouseTracker.update()
    }

    /// Hides panels per `OverlayVisibility`: for any full-screen app in pill
    /// mode, for full-screen video in notch mode (if enabled).
    func updateVisibility() {
        let hideEnabled = AppSettings.hideDuringFullScreenVideo(in: defaults)
        let entries = Array(panels)
        let result = detector.screensPlayingFullScreenVideo(entries.map { CGDisplayBounds($0.key) })

        for (index, entry) in entries.enumerated() {
            let panel = entry.value
            let isFullScreen = result.fullScreen.contains(index)
            let isVideo = result.video.contains(index)
            let hide = OverlayVisibility.isHidden(
                hasNotch: panel.model.hasNotch,
                hasFullScreenWindow: isFullScreen,
                isPlayingFullScreenVideo: isVideo,
                hideDuringFullScreenVideo: hideEnabled
            )
            if hide, panel.isVisible {
                panel.orderOut(nil)
                let reason = isVideo ? "full-screen video" : "full-screen app"
                Self.logger.info("Hiding overlay on display \(entry.key): \(reason, privacy: .public)")
            } else if !hide, !panel.isVisible {
                panel.orderFrontRegardless()
                Self.logger.info("Showing overlay on display \(entry.key)")
            }
        }

        // Playback can start or stop without any notification, so poll while
        // something is full screen.
        if result.fullScreen.isEmpty {
            fullScreenTimer?.invalidate()
            fullScreenTimer = nil
        } else if fullScreenTimer == nil {
            fullScreenTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateVisibility() }
            }
        }
        mouseTracker.update()
    }

    private func applyKeyboardFocus() {
        let mouse = NSEvent.mouseLocation
        let target = panels.values.first { $0.frame.contains(mouse) } ?? panels.values.first
        for panel in panels.values {
            panel.setAcceptsKeyboard(acceptsKeyboard && panel === target)
        }
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        perform: @escaping @MainActor (OverlayController) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                perform(self)
            }
        }
        observers.append((center, token))
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
