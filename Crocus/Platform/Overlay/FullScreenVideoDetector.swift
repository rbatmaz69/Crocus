import CoreGraphics
import Foundation
import IOKit.pwr_mgt

/// One on-screen window as reported by the window server. `bounds` uses
/// Core Graphics global coordinates (origin top-left of the primary screen).
struct WindowInfo: Equatable, Sendable {
    let ownerPID: pid_t
    let layer: Int
    let bounds: CGRect
}

protocol WindowListProviding: Sendable {
    func onScreenWindows() -> [WindowInfo]
}

protocol PowerAssertionProviding: Sendable {
    /// Whether any process currently prevents the display from sleeping (video
    /// players and browsers do while playing). `nil` if it can't be read.
    func isDisplaySleepPrevented() -> Bool?
}

/// Decides whether a full-screen video is playing on a screen: a window of
/// another app covers the whole screen and something keeps the display awake.
/// If the power assertion state can't be read, a full-screen window alone counts.
struct FullScreenVideoDetector: Sendable {
    var windows: any WindowListProviding = SystemWindowList()
    var power: any PowerAssertionProviding = SystemPowerAssertions()
    var ownPID: pid_t = ProcessInfo.processInfo.processIdentifier

    /// Tolerance for comparing window bounds with the screen bounds.
    private static let tolerance: CGFloat = 1

    /// - Parameter screenBounds: the screen in Core Graphics global coordinates
    ///   (`CGDisplayBounds`).
    func hasFullScreenWindow(on screenBounds: CGRect, in windowList: [WindowInfo]) -> Bool {
        windowList.contains { window in
            window.ownerPID != ownPID
                && window.layer == 0
                && abs(window.bounds.minX - screenBounds.minX) <= Self.tolerance
                && abs(window.bounds.minY - screenBounds.minY) <= Self.tolerance
                && abs(window.bounds.width - screenBounds.width) <= Self.tolerance
                && abs(window.bounds.height - screenBounds.height) <= Self.tolerance
        }
    }

    /// Evaluates several screens with one window-list snapshot.
    /// Returns the screens (by their bounds' index) with a full-screen video.
    func screensPlayingFullScreenVideo(_ screenBounds: [CGRect]) -> (fullScreen: Set<Int>, video: Set<Int>) {
        let windowList = windows.onScreenWindows()
        let fullScreen = Set(screenBounds.indices.filter { hasFullScreenWindow(on: screenBounds[$0], in: windowList) })
        guard !fullScreen.isEmpty else { return ([], []) }
        let displayKeptAwake = power.isDisplaySleepPrevented() ?? true
        return (fullScreen, displayKeptAwake ? fullScreen : [])
    }
}

struct SystemWindowList: WindowListProviding {
    func onScreenWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { entry in
            guard
                let pid = entry[kCGWindowOwnerPID as String] as? Int,
                let layer = entry[kCGWindowLayer as String] as? Int,
                let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return nil }
            return WindowInfo(ownerPID: pid_t(pid), layer: layer, bounds: bounds)
        }
    }
}

struct SystemPowerAssertions: PowerAssertionProviding {
    func isDisplaySleepPrevented() -> Bool? {
        var status: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&status) == kIOReturnSuccess,
              let dict = status?.takeRetainedValue() as? [String: Int]
        else { return nil }
        let keys = [kIOPMAssertPreventUserIdleDisplaySleep, kIOPMAssertionTypeNoDisplaySleep]
        return keys.contains { (dict[$0] ?? 0) > 0 }
    }
}

/// Whether the island is hidden on a screen.
enum OverlayVisibility {
    /// - Pill mode: hidden whenever an app is full screen. Without a menu bar
    ///   the floating pill would sit on top of the app's content (tabs, buttons).
    /// - Notch mode: macOS keeps full-screen content below the notch, so the
    ///   island only hides for full-screen video, if that setting is on.
    static func isHidden(
        mode: IslandMode,
        hasFullScreenWindow: Bool,
        isPlayingFullScreenVideo: Bool,
        hideDuringFullScreenVideo: Bool
    ) -> Bool {
        if mode == .pill && hasFullScreenWindow { return true }
        return hideDuringFullScreenVideo && isPlayingFullScreenVideo
    }
}
