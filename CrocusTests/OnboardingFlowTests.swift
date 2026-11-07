import Foundation
import ServiceManagement
import Testing
@testable import Crocus

@Suite struct OnboardingFlowTests {
    @Test func fourStepsWithAnExplainerPerPermission() {
        let flow = OnboardingFlow(spotifyInstalled: true)
        #expect(flow.pages == [
            .welcome,
            .permission(.calendar), .permission(.spotify), .permission(.music), .permission(.downloads), .permission(.bluetooth),
            .shortcuts, .done,
        ])
        #expect(Set(flow.pages.map(flow.step(of:))) == [1, 2, 3, 4])
    }

    @Test func noSpotifyPageWithoutSpotify() {
        let flow = OnboardingFlow(spotifyInstalled: false)
        #expect(!flow.pages.contains(.permission(.spotify)))
        #expect(flow.counter(for: .music) == "Permission 2 of 4")
    }

    @Test func countersAndTitles() {
        let flow = OnboardingFlow(spotifyInstalled: true)
        #expect(flow.counter(for: .calendar) == "Permission 1 of 5")
        #expect(flow.counter(for: .bluetooth) == "Permission 5 of 5")
        #expect(flow.windowTitle(for: .permission(.downloads)) == "Set up Crocus, step 2 of 4")
        #expect(flow.windowTitle(for: .done) == "Set up Crocus, step 4 of 4")
    }

    @Test func goesThroughInOrderAndStopsAtTheEnd() {
        let flow = OnboardingFlow(spotifyInstalled: true)
        #expect(flow.next(after: .welcome) == .permission(.calendar))
        #expect(flow.next(after: .permission(.bluetooth)) == .shortcuts)
        #expect(flow.next(after: .done) == nil)
    }

    @Test func dotsGoBackToPagesAlreadySeen() {
        let flow = OnboardingFlow(spotifyInstalled: true)
        #expect(flow.index(of: .welcome) == 0)
        #expect(flow.index(of: .done) == flow.pages.count - 1)
        #expect(OnboardingModel.canShow(0, furthest: 3, count: flow.pages.count))
        #expect(OnboardingModel.canShow(3, furthest: 3, count: flow.pages.count))
        #expect(!OnboardingModel.canShow(4, furthest: 3, count: flow.pages.count))
        #expect(!OnboardingModel.canShow(-1, furthest: 3, count: flow.pages.count))
    }

    @Test func showsOnFirstLaunchOnly() {
        let defaults = UserDefaults(suiteName: "OnboardingFlowTests")!
        defaults.removePersistentDomain(forName: "OnboardingFlowTests")
        #expect(!AppSettings.onboardingCompleted(in: defaults))
        AppSettings.setOnboardingCompleted(in: defaults)
        #expect(AppSettings.onboardingCompleted(in: defaults))
    }
}

@Suite struct LaunchAtLoginTests {
    @Test func mapsTheServiceStatus() {
        #expect(LaunchAtLogin.state(for: .enabled) == .enabled)
        #expect(LaunchAtLogin.state(for: .requiresApproval) == .needsApproval)
        #expect(LaunchAtLogin.state(for: .notRegistered) == .disabled)
        #expect(LaunchAtLogin.state(for: .notFound) == .disabled)
    }
}

@MainActor
@Suite struct OnboardingSwipeTests {
    func model() -> OnboardingModel {
        let store = IslandStore(defaults: UserDefaults(suiteName: "OnboardingSwipeTests")!)
        return OnboardingModel(
            calendar: CalendarManager(store: store),
            nowPlaying: NowPlayingManager(store: store, bridge: FakePlayerBridge()),
            downloads: DownloadsManager(store: store),
            bluetooth: BluetoothManager(store: store)
        )
    }

    @Test func swipingLeftGoesOnRightGoesBack() async {
        let model = model()
        model.swipe(.right) // nothing before the welcome page
        #expect(model.page == .welcome)
        model.swipe(.left)
        #expect(model.page == .permission(.calendar))
        model.swipe(.left)
        #expect(model.page == .permission(.spotify))
        model.swipe(.right) // going back switches direction first
        await Task.yield()
        #expect(model.page == .permission(.calendar))
        #expect(model.furthest == 2)
    }
}
