import AppKit
import SwiftUI

/// The onboarding window (560 × 440, Liquid Glass, the system's window
/// corners): opens on first launch
/// and from the menu ("Set Up Crocus…"). Closing it – or "Let's go" –
/// counts as done, so it never comes back by itself.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let makeModel: () -> OnboardingModel

    init(makeModel: @escaping () -> OnboardingModel) {
        self.makeModel = makeModel
    }

    func show() {
        if let window {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let model = makeModel()
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // Dragging the page turns it; the window moves by its top edge.
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.delegate = self

        let hosting = OnboardingHostingView(rootView: OnboardingView(model: model))
        hosting.onSwipe = { [weak model] direction in model?.swipe(direction) }
        hosting.sizingOptions = []
        hosting.focusRingType = .none
        // The glass fills the whole window: the window's own corners and edge
        // are the only frame (a glass pane with its own radius inside showed
        // as a second frame once the window was active).
        let glass = NSGlassEffectView()
        glass.contentView = hosting
        window.contentView = glass

        // VoiceOver reads the title: "Set up Crocus, step 2 of 4".
        window.title = model.flow.windowTitle(for: model.page)
        model.onPageChange = { [weak window] page in
            window?.title = model.flow.windowTitle(for: page)
        }
        model.onFinish = { [weak window] in window?.close() }

        self.window = window
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        AppSettings.setOnboardingCompleted()
        window = nil
    }
}

/// Hands two-finger swipes to the onboarding (one page per swipe).
final class OnboardingHostingView: NSHostingView<OnboardingView> {
    var onSwipe: ((SwipeDirection) -> Void)?
    private var recognizer = SwipeRecognizer()

    required init(rootView: OnboardingView) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func scrollWheel(with event: NSEvent) {
        let sample = ScrollSample(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            isPrecise: event.hasPreciseScrollingDeltas,
            phase: ScrollSample.Phase(onboarding: event.phase),
            isMomentum: !event.momentumPhase.isEmpty,
            isDirectionInverted: event.isDirectionInvertedFromDevice
        )
        if let direction = recognizer.handle(sample), direction == .left || direction == .right {
            onSwipe?(direction)
        }
    }
}

private extension ScrollSample.Phase {
    init(onboarding phase: NSEvent.Phase) {
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
