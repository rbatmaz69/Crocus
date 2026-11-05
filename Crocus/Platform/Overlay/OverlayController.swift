import AppKit
import os

/// Owns one `OverlayPanel` per connected screen, keeps them in sync with the
/// screen configuration, shows the island only on the target screen and hides
/// it during full-screen apps/videos.
@MainActor
@Observable
final class OverlayController {
    /// Debug aid: draw the panel bounds.
    var showsDebugFrame = false {
        didSet { panels.values.forEach { $0.model.showsDebugFrame = showsDebugFrame } }
    }

    /// Debug aid until the expanded state exists: let the target panel take
    /// keyboard focus.
    var acceptsKeyboard = false {
        didSet { applyKeyboardFocus() }
    }

    /// The screen that currently shows the island.
    private(set) var targetScreenID: CGDirectDisplayID?

    /// What the island shows comes from here.
    let store: IslandStore

    /// Debug: force the pill outline for a light or dark wallpaper.
    var pillOutlineOverride = PillOutlineOverride.automatic {
        didSet { applyMenuBarAppearance() }
    }

    @ObservationIgnored private var screens: [ScreenDescriptor] = []
    @ObservationIgnored private var panels: [CGDirectDisplayID: OverlayPanel] = [:]
    @ObservationIgnored private lazy var mouseTracker = MouseTracker { [unowned self] in Array(self.panels.values) }
    @ObservationIgnored private let detector = FullScreenVideoDetector()
    @ObservationIgnored private let windowList = SystemWindowList()
    @ObservationIgnored private let menuBarAppearance = MenuBarAppearanceObserver()
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var fullScreenTimer: Timer?
    @ObservationIgnored private var pointerDebounce = PointerScreenDebounce()
    @ObservationIgnored private var pointerDeadlineTask: Task<Void, Never>?
    @ObservationIgnored private var scheduledDeadline: ContinuousClock.Instant?
    @ObservationIgnored private let defaults: UserDefaults

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Overlay")
    private static let screenLogger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Screens")

    init(store: IslandStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    func start() {
        AppSettings.registerDefaults(in: defaults)
        pointerDebounce.force(ScreenDescriptor.screen(containing: NSEvent.mouseLocation, in: ScreenDescriptor.current()))
        reconcile()
        observeStore()
        mouseTracker.onPointerMove = { [weak self] location in self?.pointerMoved(to: location) }
        menuBarAppearance.onChange = { [weak self] _ in self?.applyMenuBarAppearance() }
        mouseTracker.start()

        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) {
            $0.reconcile()
        }
        observe(NotificationCenter.default, UserDefaults.didChangeNotification) {
            $0.refresh()
        }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { $0.refresh() }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { $0.refresh() }
    }

    func stop() {
        for (center, token) in observers {
            center.removeObserver(token)
        }
        observers.removeAll()
        fullScreenTimer?.invalidate()
        fullScreenTimer = nil
        pointerDeadlineTask?.cancel()
        pointerDeadlineTask = nil
        mouseTracker.stop()
        panels.values.forEach { $0.close() }
        panels.removeAll()
    }

    // MARK: - Screens

    /// Re-reads all screens: creates panels for new screens, closes panels of
    /// removed screens, updates geometry and position of the rest, then picks
    /// the target screen again.
    func reconcile() {
        let previous = Dictionary(uniqueKeysWithValues: screens.map { ($0.displayID, $0) })
        screens = ScreenDescriptor.current()

        for screen in screens {
            let geometry = screen.geometry
            if previous[screen.displayID]?.geometry != geometry {
                logGeometry(of: screen)
            }

            if let panel = panels[screen.displayID] {
                panel.model.geometry = geometry
                let frame = OverlayLayout.panelFrame(for: geometry)
                if panel.frame != frame {
                    panel.setFrame(frame, display: true)
                }
            } else {
                let panel = OverlayPanel(displayID: screen.displayID, geometry: geometry, store: store)
                panel.model.showsDebugFrame = showsDebugFrame
                panel.model.presentation = store.presentation
                panel.model.menuBarIsDark = menuBarIsDark
                panels[screen.displayID] = panel
            }
        }

        let connected = Set(screens.map(\.displayID))
        for (displayID, panel) in panels where !connected.contains(displayID) {
            panel.close()
            panels[displayID] = nil
            Self.screenLogger.info("Display \(displayID) disconnected")
        }

        // The settled pointer screen may be gone: decide again without waiting.
        if let settled = pointerDebounce.settled, !connected.contains(settled) {
            pointerDebounce.force(ScreenDescriptor.screen(containing: NSEvent.mouseLocation, in: screens))
        }

        refresh()
    }

    /// Picks the target screen and updates which panels are visible.
    func refresh() {
        let option = AppSettings.targetScreen(in: defaults)
        let target = TargetScreenResolver.resolve(
            option,
            screens: screens,
            pointerScreenID: pointerDebounce.settled,
            activeMenuBarScreenID: NSScreen.main?.displayID
        )
        if target != targetScreenID {
            targetScreenID = target
            let name = screens.first { $0.displayID == target }?.name ?? "none"
            Self.screenLogger.info("Target screen (\(option.rawValue, privacy: .public)): \(name, privacy: .public)")
            if acceptsKeyboard { applyKeyboardFocus() }
        }
        updateMenuBarClearance()
        menuBarAppearance.attach()
        updateVisibility()
    }

    private var menuBarIsDark: Bool {
        switch pillOutlineOverride {
        case .automatic: menuBarAppearance.isDark
        case .light: false
        case .dark: true
        }
    }

    private func applyMenuBarAppearance() {
        let dark = menuBarIsDark
        Self.screenLogger.info("Menu bar appearance: \(dark ? "dark" : "light", privacy: .public) (\(self.menuBarAppearance.source, privacy: .public), override \(self.pillOutlineOverride.rawValue, privacy: .public))")
        panels.values.forEach { $0.model.menuBarIsDark = dark }
    }

    /// Shrinks the right wing where menu bar items need the space.
    private func updateMenuBarClearance() {
        let windows = windowList.onScreenWindows()
        for screen in screens {
            guard let notch = screen.geometry.notchRect, let panel = panels[screen.displayID] else { continue }
            let reduced = MenuBarClearance.isRightWingReduced(
                notchRect: notch,
                screenBounds: CGDisplayBounds(screen.displayID),
                menuBarHeight: screen.geometry.menuBarHeight,
                windows: windows
            )
            if panel.model.rightWingReduced != reduced {
                panel.model.rightWingReduced = reduced
                Self.screenLogger.info("\(screen.name, privacy: .public): right wing \(reduced ? "reduced to 44 pt" : "full", privacy: .public)")
            }
        }
    }

    // MARK: - Store

    /// Pushes the store's presentation to all panels whenever it changes.
    private func observeStore() {
        let presentation = withObservationTracking {
            store.presentation
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeStore() }
        }
        for panel in panels.values where panel.model.presentation != presentation {
            panel.model.presentation = presentation
        }
    }

    // MARK: - Pointer

    private func pointerMoved(to location: CGPoint) {
        let screen = ScreenDescriptor.screen(containing: location, in: screens)
        if pointerDebounce.observe(screen, at: .now) != nil {
            refresh()
        }
        schedulePointerDeadline()
    }

    /// The pointer may stop moving before the debounce delay is over, so check
    /// again once it has passed.
    private func schedulePointerDeadline() {
        let deadline = pointerDebounce.deadline
        guard deadline != scheduledDeadline else { return }
        scheduledDeadline = deadline
        pointerDeadlineTask?.cancel()
        guard let deadline else { return }

        pointerDeadlineTask = Task { [weak self] in
            try? await Task.sleep(until: deadline, clock: .continuous)
            guard !Task.isCancelled, let self else { return }
            self.scheduledDeadline = nil
            if self.pointerDebounce.observe(self.pointerDebounce.pendingScreen, at: .now) != nil {
                self.refresh()
            }
        }
    }

    // MARK: - Visibility

    /// Shows the panel on the target screen unless `OverlayVisibility` hides it
    /// (any full-screen app in pill mode, full-screen video in notch mode).
    private func updateVisibility() {
        let hideEnabled = AppSettings.hideDuringFullScreenVideo(in: defaults)
        let entries = Array(panels)
        let result = detector.screensPlayingFullScreenVideo(entries.map { CGDisplayBounds($0.key) })

        for (index, entry) in entries.enumerated() {
            let panel = entry.value
            let isFullScreen = result.fullScreen.contains(index)
            let isVideo = result.video.contains(index)
            let hiddenByFullScreen = OverlayVisibility.isHidden(
                mode: panel.model.geometry.mode,
                hasFullScreenWindow: isFullScreen,
                isPlayingFullScreenVideo: isVideo,
                hideDuringFullScreenVideo: hideEnabled
            )
            let show = entry.key == targetScreenID && !hiddenByFullScreen

            if !show, panel.isVisible {
                panel.orderOut(nil)
                if hiddenByFullScreen, entry.key == targetScreenID {
                    let reason = isVideo ? "full-screen video" : "full-screen app"
                    Self.logger.info("Hiding overlay on display \(entry.key): \(reason, privacy: .public)")
                }
            } else if show, !panel.isVisible {
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

    // MARK: - Helpers

    private func applyKeyboardFocus() {
        for (displayID, panel) in panels {
            panel.setAcceptsKeyboard(acceptsKeyboard && displayID == targetScreenID)
        }
    }

    private func logGeometry(of screen: ScreenDescriptor) {
        let g = screen.geometry
        if let notch = g.notchRect {
            Self.screenLogger.info(
                "\(screen.name, privacy: .public) [\(screen.displayID)]: notch \(Double(notch.width)) × \(Double(notch.height)) at x \(Double(notch.minX)), frame \(Double(g.frame.width)) × \(Double(g.frame.height))"
            )
        } else {
            Self.screenLogger.info(
                "\(screen.name, privacy: .public) [\(screen.displayID)]: pill, menu bar \(Double(g.menuBarHeight)), built-in \(screen.isBuiltIn), frame \(Double(g.frame.width)) × \(Double(g.frame.height))"
            )
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
