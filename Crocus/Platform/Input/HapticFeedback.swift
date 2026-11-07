import AppKit
import SwiftUI

/// One haptic tick once the expanded island has settled (Force Touch
/// trackpads only). Cancelled if the island collapses before that.
@MainActor
final class HapticFeedback {
    private var task: Task<Void, Never>?

    /// Settling time of the expand spring.
    static var expandSettlingDuration: TimeInterval {
        CrocusSprings.expand.spring.settlingDuration
    }

    func scheduleExpandedSettled() {
        cancel()
        let delay = Self.expandSettlingDuration
        task = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
