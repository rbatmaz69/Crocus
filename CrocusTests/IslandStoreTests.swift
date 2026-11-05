import Foundation
import SwiftUI
import Testing
@testable import Crocus

@MainActor
private final class TestActivity: IslandActivity {
    let id: String
    let kind: ActivityKind
    let startedAt: Date
    var accessibilityLabel: String { id }
    let compactLeading = AnyView(EmptyView())
    let compactTrailing = AnyView(EmptyView())
    let expandedSource = AnyView(EmptyView())
    let expandedStatus = AnyView(EmptyView())
    let expandedContent = AnyView(EmptyView())

    init(_ id: String, _ kind: ActivityKind, startedAt: Date = .distantPast) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
    }
}

@MainActor
@Suite struct IslandStoreTests {
    let defaults: UserDefaults

    init() {
        let suite = "IslandStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func presentationFollowsActivities() {
        let store = IslandStore(defaults: defaults)
        #expect(store.presentation == .idle)
        store.upsert(TestActivity("timer", .timer))
        #expect(store.presentation == .compact)
        #expect(store.primaryActivity?.id == "timer")
        store.upsert(TestActivity("music", .music))
        #expect(store.presentation == .minimal)
        #expect(store.secondaryActivity?.id == "music")
        store.expand()
        #expect(store.presentation == .expanded)
        store.collapse()
        store.removeAll()
        #expect(store.presentation == .idle)
    }

    @Test func toggleAndCards() {
        let store = IslandStore(defaults: defaults)
        store.toggle()
        #expect(store.presentation == .idle)
        store.upsert(TestActivity("timer", .timer))
        store.upsert(TestActivity("music", .music))
        store.toggle()
        #expect(store.presentation == .expanded)
        store.showNextCard()
        #expect(store.primaryActivity?.id == "music")
        store.toggle()
        #expect(store.presentation == .minimal)
    }

    @Test func eventContentAndLabel() {
        let store = IslandStore(defaults: defaults)
        store.upsert(TestActivity("timer", .timer))
        let event = IslandEvent(
            kind: .charging, accessibilityLabel: "Charging",
            compactLeading: AnyView(EmptyView()), compactTrailing: AnyView(EmptyView())
        )
        store.post(event)
        #expect(store.currentEvent?.id == event.id)
        #expect(store.primaryActivity == nil)
        #expect(store.accessibilityLabel == "Charging")
    }

    @Test func priorityChangeInSettingsResorts() async throws {
        let store = IslandStore(defaults: defaults)
        store.upsert(TestActivity("timer", .timer))
        store.upsert(TestActivity("music", .music))
        #expect(store.primaryActivity?.id == "timer")

        AppSettings.setActivityPriority(ActivityPriority(storedOrder: ["music"]), in: defaults)
        // The change notification is delivered on the main queue.
        try await Task.sleep(for: .milliseconds(50))
        #expect(store.primaryActivity?.id == "music")
    }
}
