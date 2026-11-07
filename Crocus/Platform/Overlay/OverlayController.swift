import AppKit
import os
import SwiftUI

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
    #if DEBUG
    @ObservationIgnored private let frameMonitor = FrameMonitor()
    #endif
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
    @ObservationIgnored private let clickOutside = ClickOutsideMonitor()
    @ObservationIgnored private let haptics = HapticFeedback()
    @ObservationIgnored private let hotKey = GlobalHotKey()
    /// C5: panels a running screen change shows and hides itself.
    @ObservationIgnored private var screenChangePanels: Set<CGDirectDisplayID> = []
    @ObservationIgnored private var flightWindows: [ScreenFlightPanel] = []
    /// The target screen changed while expanded: move once it is collapsed.
    @ObservationIgnored private var screenChangeDeferred = false

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
        hotKey.onPress = { [weak self] in self?.store.toggle() }
        hotKey.register(AppSettings.globalShortcut(in: defaults))
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
        clickOutside.stop()
        haptics.cancel()
        hotKey.unregister()
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
                panel.model.hoverStyle = AppSettings.hoverStyle(in: defaults)
                panel.onEscape = { [weak self] in self?.store.collapse() }
                panel.onArrow = { [weak self] direction in self?.stepCard(CardNavigation.step(forArrow: direction)) }
                panel.onSwipe = { [weak self] direction in self?.handleSwipe(direction) }
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
        var target = TargetScreenResolver.resolve(
            option,
            screens: screens,
            pointerScreenID: pointerDebounce.settled,
            activeMenuBarScreenID: NSScreen.main?.displayID
        )
        if target != targetScreenID, let current = targetScreenID, panels[current] != nil {
            if !screenChangePanels.isEmpty {
                // Mid-flight: the island never turns around in the air; look
                // again once it has landed.
                target = current
            } else if store.presentation == .expanded {
                // Don't pull the open island away from under the pointer.
                screenChangeDeferred = true
                target = current
            }
        }
        if target != targetScreenID {
            let previous = targetScreenID
            targetScreenID = target
            let name = screens.first { $0.displayID == target }?.name ?? "none"
            Self.screenLogger.info("Target screen (\(option.rawValue, privacy: .public)): \(name, privacy: .public)")
            applyKeyboardFocus()
            beginScreenChange(from: previous, to: target)
        }
        updateMenuBarClearance()
        menuBarAppearance.attach()
        applyInputSettings()
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
                extraTrailingWidth: MenuBarClearance.extraWidth(for: store.presentation),
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
        let previous = panels.values.first?.model.presentation
        for panel in panels.values where panel.model.presentation != presentation {
            panel.model.presentation = presentation
        }
        guard presentation != previous else { return }
        #if DEBUG
        if let target = targetScreenID, let view = panels[target]?.contentView {
            frameMonitor.measure("\(previous.map { String(describing: $0) } ?? "?") → \(presentation)", on: view)
        }
        #endif
        updateMenuBarClearance()
        applyKeyboardFocus()
        if screenChangeDeferred, presentation != .expanded {
            // Moves once the island has closed (collapse spring).
            screenChangeDeferred = false
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(CrocusMotion.seconds(0.45)))
                self?.refresh()
            }
        }
        updateClickOutside()
        if presentation == .expanded {
            if AppSettings.hapticFeedback(in: defaults) { haptics.scheduleExpandedSettled() }
        } else {
            haptics.cancel()
        }
    }

    // MARK: - Interaction

    private func handleSwipe(_ direction: SwipeDirection) {
        switch direction {
        case .down: store.expand()
        case .up: store.collapse()
        case .left, .right: stepCard(CardNavigation.step(forSwipe: direction))
        }
    }

    /// +1 = next card, -1 = previous; only while expanded.
    private func stepCard(_ step: Int) {
        guard store.presentation == .expanded else { return }
        let panel = targetScreenID.flatMap { panels[$0] } ?? panels.values.first
        panel?.model.stepCard(step)
    }

    /// While expanded, a click outside the island collapses it.
    private func updateClickOutside() {
        if store.presentation == .expanded {
            clickOutside.start { [weak self] location in
                guard let self, let target = self.targetScreenID, let panel = self.panels[target] else { return }
                if !panel.hitRegion.contains(location) {
                    self.store.collapse()
                }
            }
        } else {
            clickOutside.stop()
        }
    }

    /// Hover style and global shortcut follow the settings.
    private func applyInputSettings() {
        let style = AppSettings.hoverStyle(in: defaults)
        for panel in panels.values where panel.model.hoverStyle != style {
            panel.model.hoverStyle = style
        }
        hotKey.register(AppSettings.globalShortcut(in: defaults))
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

        for (index, entry) in entries.enumerated() where !screenChangePanels.contains(entry.key) {
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

    // MARK: - Screen change (C5)

    /// Moves the island to the new target screen: it flies (compact or
    /// minimal), cross-fades (idle, Reduce Motion) or – with the setting off,
    /// or when the old screen is gone – simply appears there.
    private func beginScreenChange(from old: CGDirectDisplayID?, to new: CGDirectDisplayID?) {
        guard AppSettings.animateScreenChange(in: defaults),
              let old, let new, old != new,
              let source = panels[old], let destination = panels[new], source.isVisible,
              let sourceScreen = screens.first(where: { $0.displayID == old }),
              let destinationScreen = screens.first(where: { $0.displayID == new }),
              !isHiddenByFullScreen(new, panel: destination)
        else { return }

        screenChangePanels = [old, new]
        let presentation = store.presentation
        if ScreenFlight.flies(presentation: presentation, enabled: true, reduceMotion: CrocusMotion.reduceMotion) {
            Self.screenLogger.info("Screen change: flying \(sourceScreen.name, privacy: .public) → \(destinationScreen.name, privacy: .public)")
            fly(from: source, on: sourceScreen, to: destination, on: destinationScreen, presentation: presentation)
        } else {
            crossFade(from: source, to: destination)
        }
    }

    /// Reduce Motion and the idle island: out on the old screen (150 ms), in
    /// on the new one (200 ms).
    private func crossFade(from source: OverlayPanel, to destination: OverlayPanel) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = CrocusMotion.seconds(0.15)
            source.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                source.orderOut(nil)
                source.alphaValue = 1
            }
        }
        destination.alphaValue = 0
        destination.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = CrocusMotion.seconds(0.20)
            destination.animator().alphaValue = 1
        } completionHandler: {
            MainActor.assumeIsolated { self.endScreenChange() }
        }
    }

    /// C5: the content goes out (120 ms), the flight windows take over the
    /// island's exact outline, fly it across and hand it to the destination
    /// panel, whose content then comes in like C1.
    private func fly(
        from source: OverlayPanel, on sourceScreen: ScreenDescriptor,
        to destination: OverlayPanel, on destinationScreen: ScreenDescriptor,
        presentation: IslandPresentation
    ) {
        let start = ScreenFlight.form(on: sourceScreen.geometry, presentation: presentation, rightWingReduced: source.model.rightWingReduced)
        let end = ScreenFlight.form(on: destinationScreen.geometry, presentation: presentation, rightWingReduced: destination.model.rightWingReduced)
        let flight = ScreenFlight(
            from: start.form, fromAttached: start.attached, fromScreen: sourceScreen.frame,
            to: end.form, toAttached: end.attached, toScreen: destinationScreen.frame
        )
        let dark = menuBarIsDark
        // The destination draws along, invisibly, from now on: when the
        // island lands it is already rendered – no cold first frame. Its
        // own island stays hidden while the flight draws it.
        destination.model.flightIslandHidden = true
        destination.model.flightContentHidden = true
        destination.model.flightDropHidden = true
        destination.model.flightShadowHidden = true
        destination.alphaValue = 0
        destination.orderFrontRegardless()
        let sourceContent = AnyView(Self.flightContent(model: source.model, on: sourceScreen.geometry))
        let content = AnyView(Self.flightContent(model: destination.model, on: destinationScreen.geometry))

        // The flight windows draw their first frame (the island exactly as it
        // is, content and all) invisibly before anything moves – no cold start.
        let clock = FlightClock()
        flightWindows = [sourceScreen, destinationScreen].map {
            let isSource = $0.displayID == sourceScreen.displayID
            return ScreenFlightPanel(
                screenFrame: $0.frame, flight: flight, clock: clock, menuBarIsDark: dark,
                sourceContent: isSource ? sourceContent : nil,
                content: isSource ? nil : content
            )
        }
        flightWindows.forEach {
            $0.alphaValue = 0
            $0.orderFrontRegardless()
        }

        Task { @MainActor [weak self, weak source, weak destination] in
            try? await Task.sleep(for: .milliseconds(60))
            guard let self else { return }
            let startDate = Date()
            /// Waits until `time` (flight seconds, unscaled) after the start.
            func wait(until time: Double) async {
                let left = CrocusMotion.seconds(time) - Date().timeIntervalSince(startDate)
                if left > 0 { try? await Task.sleep(for: .seconds(left)) }
            }
            @MainActor func isLive(_ panel: OverlayPanel?) -> OverlayPanel? {
                panel.flatMap { panel in self.panels.values.contains { $0 === panel } ? panel : nil }
            }

            // Go: the flight covers the island exactly and starts to move;
            // the island fades out underneath while the flight's shadow comes in.
            clock.start = startDate
            self.flightWindows.forEach { $0.alphaValue = 1 }
            #if DEBUG
            if let view = self.flightWindows.last?.contentView {
                self.frameMonitor.measure("screen flight", on: view)
            }
            #endif
            if let source {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = CrocusMotion.seconds(ScreenFlight.departure)
                    source.animator().alphaValue = 0
                } completionHandler: {
                    MainActor.assumeIsolated {
                        source.orderOut(nil)
                        source.alphaValue = 1
                    }
                }
            }

            // Arriving: the destination shows its drop/circle, coming in with
            // the content the flight draws (its island is still hidden).
            await wait(until: ScreenFlight.contentStart)
            if let destination = isLive(destination) {
                destination.alphaValue = 1
                withAnimation(.easeOut(duration: CrocusMotion.seconds(0.32))) {
                    destination.model.flightDropHidden = false
                }
            }

            // Handover: the island appears in full right under the flight –
            // the same opaque image, so nothing changes on screen. Only the
            // see-through shadow moves over: the island's comes in while the
            // flight's goes, on the same linear curve. Then the flight goes.
            await wait(until: ScreenFlight.handover)
            if let destination = isLive(destination) {
                destination.model.flightContentHidden = false
                destination.model.flightIslandHidden = false
                withAnimation(.linear(duration: CrocusMotion.seconds(ScreenFlight.handoverFade))) {
                    destination.model.flightShadowHidden = false
                }
            }
            await wait(until: ScreenFlight.duration)
            self.flightWindows.forEach { $0.close() }
            self.flightWindows.removeAll()
            self.endScreenChange()
        }
    }

    /// The destination island's compact content at its final size, for the
    /// flight to draw while it lands.
    private static func flightContent(model: OverlayPanelModel, on geometry: ScreenGeometry) -> some View {
        let metrics: IslandLayoutMetrics = geometry.notchRect.map {
            .notch(notchSize: $0.size, rightWingReduced: model.rightWingReduced)
        } ?? .pill
        return IslandCompactContent(model: model, metrics: metrics)
    }

    /// Done: normal visibility again, and any change that waited.
    private func endScreenChange() {
        screenChangePanels = []
        refresh()
    }

    private func isHiddenByFullScreen(_ displayID: CGDirectDisplayID, panel: OverlayPanel) -> Bool {
        let result = detector.screensPlayingFullScreenVideo([CGDisplayBounds(displayID)])
        return OverlayVisibility.isHidden(
            mode: panel.model.geometry.mode,
            hasFullScreenWindow: result.fullScreen.contains(0),
            isPlayingFullScreenVideo: result.video.contains(0),
            hideDuringFullScreenVideo: AppSettings.hideDuringFullScreenVideo(in: defaults)
        )
    }

    // MARK: - Helpers

    /// Only the expanded island on the target screen takes keyboard focus
    /// (Esc, arrows, Tab); it hands focus back on collapse.
    private func applyKeyboardFocus() {
        let expanded = store.presentation == .expanded
        for (displayID, panel) in panels {
            panel.setAcceptsKeyboard(expanded && displayID == targetScreenID)
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
