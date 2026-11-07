import Foundation

/// One permission the onboarding asks for, each on its own explainer page.
enum OnboardingPermission: String, CaseIterable, Sendable {
    case calendar, spotify, music, downloads, bluetooth
}

enum OnboardingPage: Hashable, Sendable {
    case welcome
    case permission(OnboardingPermission)
    case shortcuts
    case done
}

/// Where a permission stands, shown on its page.
enum OnboardingPermissionState: Equatable, Sendable {
    case notAsked
    case granted
    case denied
}

/// The onboarding's pages in order (board 10): welcome, the permissions,
/// shortcuts, done – 4 steps, the permissions being step 2. Pure, so the
/// order, counters and titles are testable.
struct OnboardingFlow: Equatable, Sendable {
    static let stepCount = 4

    let pages: [OnboardingPage]

    /// Spotify's page only when Spotify is installed.
    init(spotifyInstalled: Bool) {
        let permissions = OnboardingPermission.allCases.filter { $0 != .spotify || spotifyInstalled }
        pages = [.welcome] + permissions.map(OnboardingPage.permission) + [.shortcuts, .done]
    }

    var permissions: [OnboardingPermission] {
        pages.compactMap { if case .permission(let permission) = $0 { permission } else { nil } }
    }

    /// 1…4: every permission page is step 2.
    func step(of page: OnboardingPage) -> Int {
        switch page {
        case .welcome: 1
        case .permission: 2
        case .shortcuts: 3
        case .done: 4
        }
    }

    /// VoiceOver reads the window title: "Set up Crocus, step 2 of 4".
    func windowTitle(for page: OnboardingPage) -> String {
        "Set up Crocus, step \(step(of: page)) of \(Self.stepCount)"
    }

    /// "Permission 2 of 5".
    func counter(for permission: OnboardingPermission) -> String {
        let index = (permissions.firstIndex(of: permission) ?? 0) + 1
        return "Permission \(index) of \(permissions.count)"
    }

    /// Position of the page among all pages, for the page dots.
    func index(of page: OnboardingPage) -> Int {
        pages.firstIndex(of: page) ?? 0
    }

    func next(after page: OnboardingPage) -> OnboardingPage? {
        guard let index = pages.firstIndex(of: page), index + 1 < pages.count else { return nil }
        return pages[index + 1]
    }
}
