import Foundation
import Testing
@testable import Crocus

@Suite("Menu bar panel")
struct MenuBarPanelTests {
    // MARK: Permissions

    @Test func nothingMissingAsksForNothing() {
        let items = MenuBarAttention.items(
            calendar: .granted,
            players: [.spotify: .granted, .music: .unavailable],
            bluetooth: .granted,
            downloadsFolder: URL(fileURLWithPath: "/Users/me/Downloads")
        )
        #expect(items.isEmpty)
    }

    @Test func everythingMissingInAFixedOrder() {
        let items = MenuBarAttention.items(
            calendar: .notDetermined,
            players: [.spotify: .notDetermined, .music: .denied],
            bluetooth: .denied,
            downloadsFolder: nil
        )
        #expect(items.map(\.subject) == [.calendar, .player(.spotify), .player(.music), .bluetooth, .downloadsFolder])
        #expect(items.map(\.action) == [.request, .request, .openSystemSettings, .openSystemSettings, .chooseFolder])
        #expect(items.map(\.buttonTitle) == ["Allow", "Allow", "Open…", "Open…", "Choose…"])
    }

    @Test func switchedOffTypesNeverAsk() {
        let items = MenuBarAttention.items(
            calendar: .denied,
            players: [.spotify: .denied],
            bluetooth: .notDetermined,
            downloadsFolder: nil,
            disabledActivities: [.calendar, .music, .download],
            disabledEvents: [.bluetooth]
        )
        #expect(items.isEmpty)
    }

    @Test func idsAreUnique() {
        let items = MenuBarAttention.items(
            calendar: .denied, players: [.spotify: .denied, .music: .notDetermined], bluetooth: .denied, downloadsFolder: nil
        )
        #expect(Set(items.map(\.id)).count == items.count)
    }

    // MARK: Status line

    @Test func statusLine() {
        #expect(MenuBarStatus.line(activityCount: 3, screenName: "MacBook display", islandHidden: false) == "3 activities · MacBook display")
        #expect(MenuBarStatus.line(activityCount: 1, screenName: nil, islandHidden: false) == "1 activity")
        #expect(MenuBarStatus.line(activityCount: 0, screenName: "Studio Display", islandHidden: false) == "No activities")
        #expect(MenuBarStatus.line(activityCount: 2, screenName: "Studio Display", islandHidden: true) == "Island hidden")
    }

    // MARK: Timer row

    @Test func timerRowDetail() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        var timer = TimerState.timer(duration: 300, now: start)
        #expect(TimerFormat.panelDetail(timer, now: start.addingTimeInterval(28)) == "04:32 remaining")
        timer.pause(now: start.addingTimeInterval(28))
        #expect(TimerFormat.panelDetail(timer, now: start.addingTimeInterval(60)) == "04:32 · paused")
        var finished = TimerState.timer(duration: 60, now: start)
        _ = finished.finishIfDue(now: start.addingTimeInterval(61))
        #expect(TimerFormat.panelDetail(finished, now: start.addingTimeInterval(61)) == "Finished")
        let stopwatch = TimerState.stopwatch(now: start)
        #expect(TimerFormat.panelDetail(stopwatch, now: start.addingTimeInterval(65)) == "01:05")
    }

    // MARK: "Show island"

    @Test func hiddenIslandIsNeverShown() {
        #expect(OverlayVisibility.showsIsland(isTargetScreen: true, hiddenByFullScreen: false, islandHidden: false))
        #expect(!OverlayVisibility.showsIsland(isTargetScreen: true, hiddenByFullScreen: false, islandHidden: true))
        #expect(!OverlayVisibility.showsIsland(isTargetScreen: true, hiddenByFullScreen: true, islandHidden: false))
        #expect(!OverlayVisibility.showsIsland(isTargetScreen: false, hiddenByFullScreen: false, islandHidden: false))
    }

    @Test func shortcutDoesNothingWhileHidden() {
        #expect(OverlayVisibility.shortcutToggles(islandHidden: false))
        #expect(!OverlayVisibility.shortcutToggles(islandHidden: true))
    }

    @Test func islandIsShownByDefaultAndTheSwitchPersists() {
        let suite = "MenuBarPanelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        AppSettings.registerDefaults(in: defaults)
        #expect(!AppSettings.islandHidden(in: defaults))
        AppSettings.setIslandHidden(true, in: defaults)
        #expect(AppSettings.islandHidden(in: defaults))
    }

    @Test func everyTargetIsAtLeast28Points() {
        #expect(MenuBarMetrics.hitSize >= 28)
        #expect(MenuBarMetrics.footerRowHeight >= 28)
        #expect(MenuBarMetrics.rowHeight >= 28)
    }
}
