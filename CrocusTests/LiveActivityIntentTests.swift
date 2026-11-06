import Foundation
import Testing
@testable import Crocus

@MainActor
@Suite struct LiveActivityIntentTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_000_000) }

    let clock = Clock()

    func makeStore() -> IslandStore {
        let suite = "LiveActivityIntentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return IslandStore(defaults: defaults)
    }

    func makeManager(_ store: IslandStore) -> LiveActivityManager {
        let clock = clock
        return LiveActivityManager(store: store, now: { clock.now }, openURL: { _ in })
    }

    func handler(_ manager: LiveActivityManager, id: String = "generated") -> LiveActivityIntentHandler {
        LiveActivityIntentHandler(manager: manager, symbolExists: { $0 == "hammer" }, makeID: { id })
    }

    // MARK: Start

    @Test func startReturnsTheActivity() throws {
        let store = makeStore()
        let manager = makeManager(store)
        let entity = try handler(manager).start(title: "Build", symbol: "hammer", progress: 0, status: "Starting", identifier: "build")
        #expect(entity == LiveActivityEntity(id: "build", title: "Build", symbol: "hammer"))
        #expect(store.presentation == .compact)
        let state = try #require(manager.activities["build"]?.state)
        #expect(state.progress == .value(0))
        #expect(state.status == "Starting")
        #expect(state.source == LiveActivityIntentHandler.defaultSource)
    }

    @Test func emptyIdentifierCreatesOne() throws {
        let manager = makeManager(makeStore())
        #expect(try handler(manager, id: "auto").start(title: "A").id == "auto")
        #expect(try handler(manager, id: "auto2").start(title: "B", identifier: "").id == "auto2")
    }

    @Test(arguments: 0..<20)
    func generatedIDsAreValid(_: Int) throws {
        let id = LiveActivityIntentHandler.generatedID()
        #expect(try LiveActivityValidation.id(id) == id)
    }

    @Test func invalidIdentifierIsRejected() {
        let manager = makeManager(makeStore())
        #expect(throws: LiveActivityError.invalidID("../x")) { try handler(manager).start(title: "A", identifier: "../x") }
        #expect(manager.activities.isEmpty)
    }

    @Test func blankTitleIsRejected() {
        let manager = makeManager(makeStore())
        #expect(throws: LiveActivityError.missingParameter("title")) { try handler(manager).start(title: "  ") }
    }

    @Test func progressRules() throws {
        let manager = makeManager(makeStore())
        _ = try handler(manager).start(title: "A", identifier: "a")
        #expect(manager.activities["a"]?.state.progress == .indeterminate)
        _ = try handler(manager).start(title: "B", progress: 1.7, identifier: "b")
        #expect(manager.activities["b"]?.state.progress == .value(1))
        #expect(throws: LiveActivityError.self) { try handler(manager).start(title: "C", progress: .nan, identifier: "c") }
        #expect(manager.activities["c"] == nil)
    }

    @Test func unknownSymbolFallsBack() throws {
        let entity = try handler(makeManager(makeStore())).start(title: "A", symbol: "no.such.symbol")
        #expect(entity.symbol == LiveActivityValidation.fallbackSymbol)
    }

    @Test func onlyWebAndFileActions() throws {
        let manager = makeManager(makeStore())
        _ = try handler(manager).start(title: "A", action: URL(string: "file:///tmp/build.log"), actionTitle: "Open Log", identifier: "a")
        #expect(manager.activities["a"]?.state.action == LiveActivityAction(url: URL(string: "file:///tmp/build.log")!, title: "Open Log"))
        _ = try handler(manager).start(title: "B", action: URL(string: "javascript:alert(1)"), identifier: "b")
        #expect(manager.activities["b"]?.state.action == nil)
    }

    // MARK: Update and End reuse the returned entity

    @Test func updateAndEndUseTheReturnedEntity() throws {
        let store = makeStore()
        let manager = makeManager(store)
        let started = try handler(manager).start(title: "Build", progress: 0)

        let updated = try handler(manager).update(id: started.id, progress: 0.4, status: "128 of 320")
        #expect(updated == started)
        #expect(manager.activities[started.id]?.state.progress == .value(0.4))
        #expect(manager.activities[started.id]?.state.status == "128 of 320")

        try handler(manager).end(id: started.id, result: .success, text: "Build finished")
        #expect(manager.activities[started.id]?.state.phase == .ended(.success, text: "Build finished", at: clock.now))

        // The result is shown for 3 s, then the activity disappears.
        clock.now += 3
        manager.tick()
        #expect(manager.activities.isEmpty)
        #expect(store.presentation == .idle)
    }

    @Test func updateWithoutProgressKeepsIt() throws {
        let manager = makeManager(makeStore())
        _ = try handler(manager).start(title: "A", progress: 0.3, identifier: "a")
        _ = try handler(manager).update(id: "a", status: "Still going")
        #expect(manager.activities["a"]?.state.progress == .value(0.3))
        #expect(manager.activities["a"]?.state.status == "Still going")
    }

    @Test func unknownOrEndedActivitiesAreReported() throws {
        let manager = makeManager(makeStore())
        #expect(throws: LiveActivityError.notRunning("nope")) { try handler(manager).update(id: "nope", progress: 1) }
        #expect(throws: LiveActivityError.notRunning("nope")) { try handler(manager).end(id: "nope", result: .failure) }

        _ = try handler(manager).start(title: "A", identifier: "a")
        try handler(manager).end(id: "a", result: .cancelled)
        #expect(throws: LiveActivityError.notRunning("a")) { try handler(manager).update(id: "a", progress: 0.5) }
        #expect(throws: LiveActivityError.notRunning("a")) { try handler(manager).end(id: "a", result: .success) }
        #expect(manager.activities["a"]?.state.phase == .ended(.cancelled, text: nil, at: clock.now))
    }

    @Test func errorsReadWellInShortcuts() {
        #expect(String(localized: LiveActivityError.notRunning("build").localizedStringResource) == "Activity 'build' is not running.")
    }

    // MARK: Entity query

    @Test func queryResolvesRunningAndPlaceholderIDs() throws {
        let manager = makeManager(makeStore())
        _ = try handler(manager).start(title: "Build", symbol: "hammer", identifier: "build")
        let entities = LiveActivityEntityQuery.entities(for: ["build", "gone", "../x"], in: manager)
        #expect(entities == [
            LiveActivityEntity(id: "build", title: "Build", symbol: "hammer"),
            LiveActivityEntity(placeholderFor: "gone"),
        ])
    }

    @Test func suggestionsAreRunningActivitiesNewestFirst() throws {
        let manager = makeManager(makeStore())
        _ = try handler(manager).start(title: "Old", identifier: "old")
        clock.now += 1
        _ = try handler(manager).start(title: "New", identifier: "new")
        clock.now += 1
        _ = try handler(manager).start(title: "Done", identifier: "done")
        try handler(manager).end(id: "done", result: .success)
        #expect(LiveActivityEntityQuery.suggestedEntities(in: manager).map(\.id) == ["new", "old"])
    }

    // MARK: Same behaviour as the URL scheme

    @Test func behavesLikeTheURLScheme() throws {
        let urlManager = makeManager(makeStore())
        let intentManager = makeManager(makeStore())
        let symbols: LiveActivityURLParser.SymbolCheck = { $0 == "hammer" }
        func open(_ string: String) throws {
            urlManager.handle(try LiveActivityURLParser.parse(URL(string: string)!, symbolExists: symbols).get())
        }
        func expectSameState(_ comment: Comment) {
            #expect(urlManager.activities["build"]?.state == intentManager.activities["build"]?.state, comment)
        }

        try open("crocus://start?id=build&title=Build&symbol=hammer&progress=0&status=Starting&source=Shortcuts&action=file:///tmp/build.log&actionTitle=Open%20Log")
        _ = try handler(intentManager).start(
            title: "Build", symbol: "hammer", progress: 0, status: "Starting",
            action: URL(string: "file:///tmp/build.log"), actionTitle: "Open Log", identifier: "build"
        )
        expectSameState("start")

        clock.now += 10
        try open("crocus://update?id=build&progress=0.4&status=128%20of%20320")
        _ = try handler(intentManager).update(id: "build", progress: 0.4, status: "128 of 320")
        expectSameState("update")

        clock.now += 10
        try open("crocus://end?id=build&result=failure&text=Tests%20failed")
        try handler(intentManager).end(id: "build", result: .failure, text: "Tests failed")
        expectSameState("end")
    }
}
