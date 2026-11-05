import Foundation
import Testing
@testable import Crocus

@Suite struct URLRouterTests {
    let router = URLRouter(symbolExists: { _ in true })

    @Test func routesLiveActivityCommands() throws {
        let url = try #require(URL(string: "crocus://end?id=build&result=failure"))
        #expect(router.action(for: url) == .liveActivity(.end(id: "build", result: .failure, text: nil)))
    }

    @Test func schemeIsCaseInsensitive() throws {
        let url = try #require(URL(string: "CROCUS://update?id=x"))
        #expect(router.action(for: url) != nil)
    }

    @Test func invalidCrocusURLsAreReported() throws {
        let url = try #require(URL(string: "crocus://explode?id=x"))
        guard case .invalid(let reason) = router.action(for: url) else {
            Issue.record("expected .invalid")
            return
        }
        #expect(reason.contains("explode"))
    }

    @Test(arguments: ["insel://test", "https://example.com", "file:///tmp/x"])
    func rejectsOtherSchemes(_ string: String) throws {
        let url = try #require(URL(string: string))
        #expect(router.action(for: url) == nil)
    }
}
