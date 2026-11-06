#if DEBUG
import AppKit
import QuartzCore
import os

/// Debug: after each island transition, watches the display's frames for a
/// second and logs dropped frames and the longest gap – to tell real
/// stutter (frames missed) from choreography that only looks busy.
@MainActor
final class FrameMonitor: NSObject {
    private var link: CADisplayLink?
    private var stamps: [CFTimeInterval] = []
    private var frameDuration: CFTimeInterval = 1.0 / 60
    private var label = ""
    private var stopTask: Task<Void, Never>?

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "Frames")
    static let window: Duration = .milliseconds(900)

    func measure(_ label: String, on view: NSView) {
        stop(report: false)
        self.label = label
        stamps = []
        let link = view.displayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: Self.window)
            guard !Task.isCancelled else { return }
            self?.stop(report: true)
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        stamps.append(link.timestamp)
        frameDuration = link.duration > 0 ? link.duration : frameDuration
    }

    private func stop(report: Bool) {
        stopTask?.cancel()
        link?.invalidate()
        link = nil
        guard report, stamps.count > 1 else { return }
        let gaps = zip(stamps.dropFirst(), stamps).map { $0 - $1 }
        let dropped = gaps.reduce(0) { $0 + max(Int(($1 / frameDuration).rounded()) - 1, 0) }
        let worst = (gaps.max() ?? 0) * 1000
        let hz = Int((1 / frameDuration).rounded())
        Self.logger.info("\(self.label, privacy: .public): \(self.stamps.count, privacy: .public) frames at \(hz, privacy: .public) Hz, dropped \(dropped, privacy: .public), worst gap \(String(format: "%.1f", worst), privacy: .public) ms")
    }
}
#endif
