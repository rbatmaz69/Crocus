import CoreGraphics
import Testing
@testable import Crocus

private struct FakeWindows: WindowListProviding {
    let windows: [WindowInfo]
    func onScreenWindows() -> [WindowInfo] { windows }
}

private struct FakePower: PowerAssertionProviding {
    let prevented: Bool?
    func isDisplaySleepPrevented() -> Bool? { prevented }
}

@Suite struct FullScreenVideoDetectorTests {
    static let ownPID: pid_t = 1
    static let otherPID: pid_t = 42
    // Core Graphics coordinates: built-in display at the origin, external to the right.
    static let builtIn = CGRect(x: 0, y: 0, width: 1470, height: 956)
    static let external = CGRect(x: 1470, y: 0, width: 2560, height: 1440)

    func detector(_ windows: [WindowInfo], prevented: Bool?) -> FullScreenVideoDetector {
        FullScreenVideoDetector(
            windows: FakeWindows(windows: windows),
            power: FakePower(prevented: prevented),
            ownPID: Self.ownPID
        )
    }

    func fullScreen(_ bounds: CGRect, pid: pid_t = otherPID, layer: Int = 0) -> WindowInfo {
        WindowInfo(ownerPID: pid, layer: layer, bounds: bounds)
    }

    @Test func fullScreenWindowWithDisplayAwakeIsVideo() {
        let result = detector([fullScreen(Self.builtIn)], prevented: true)
            .screensPlayingFullScreenVideo([Self.builtIn, Self.external])
        #expect(result.fullScreen == [0])
        #expect(result.video == [0])
    }

    @Test func fullScreenWithoutPlaybackIsNotVideo() {
        let result = detector([fullScreen(Self.builtIn)], prevented: false)
            .screensPlayingFullScreenVideo([Self.builtIn])
        #expect(result.fullScreen == [0])
        #expect(result.video.isEmpty)
    }

    @Test func unreadablePowerStateFallsBackToFullScreen() {
        let result = detector([fullScreen(Self.external)], prevented: nil)
            .screensPlayingFullScreenVideo([Self.builtIn, Self.external])
        #expect(result.video == [1])
    }

    @Test func ownWindowsAreIgnored() {
        let result = detector([fullScreen(Self.builtIn, pid: Self.ownPID)], prevented: true)
            .screensPlayingFullScreenVideo([Self.builtIn])
        #expect(result.video.isEmpty)
    }

    @Test func otherLayersAreIgnored() {
        let result = detector([fullScreen(Self.builtIn, layer: 25)], prevented: true)
            .screensPlayingFullScreenVideo([Self.builtIn])
        #expect(result.video.isEmpty)
    }

    @Test func windowOnOtherScreenOnlyAffectsThatScreen() {
        let result = detector([fullScreen(Self.external)], prevented: true)
            .screensPlayingFullScreenVideo([Self.builtIn, Self.external])
        #expect(result.video == [1])
    }

    @Test func regularWindowIsNotFullScreen() {
        let window = WindowInfo(ownerPID: Self.otherPID, layer: 0, bounds: CGRect(x: 0, y: 33, width: 1470, height: 923))
        let result = detector([window], prevented: true).screensPlayingFullScreenVideo([Self.builtIn])
        #expect(result.fullScreen.isEmpty)
    }
}

@Suite struct OverlayVisibilityTests {
    @Test(arguments: [true, false])
    func pillHidesForAnyFullScreenApp(video: Bool) {
        #expect(OverlayVisibility.isHidden(
            hasNotch: false, hasFullScreenWindow: true,
            isPlayingFullScreenVideo: video, hideDuringFullScreenVideo: false
        ))
    }

    @Test func notchStaysForFullScreenAppWithoutVideo() {
        #expect(!OverlayVisibility.isHidden(
            hasNotch: true, hasFullScreenWindow: true,
            isPlayingFullScreenVideo: false, hideDuringFullScreenVideo: true
        ))
    }

    @Test func notchHidesForVideoOnlyWhenEnabled() {
        #expect(OverlayVisibility.isHidden(
            hasNotch: true, hasFullScreenWindow: true,
            isPlayingFullScreenVideo: true, hideDuringFullScreenVideo: true
        ))
        #expect(!OverlayVisibility.isHidden(
            hasNotch: true, hasFullScreenWindow: true,
            isPlayingFullScreenVideo: true, hideDuringFullScreenVideo: false
        ))
    }

    @Test(arguments: [true, false])
    func visibleWithoutFullScreen(hasNotch: Bool) {
        #expect(!OverlayVisibility.isHidden(
            hasNotch: hasNotch, hasFullScreenWindow: false,
            isPlayingFullScreenVideo: false, hideDuringFullScreenVideo: true
        ))
    }
}
