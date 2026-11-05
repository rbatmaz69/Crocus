import Foundation
import Testing
@testable import Crocus

@Suite struct URLRouterTests {
    let router = URLRouter()

    @Test func acceptsCrocusScheme() throws {
        let url = try #require(URL(string: "crocus://activity/start?id=1"))
        #expect(router.action(for: url) == .unknown(host: "activity", path: "/start"))
    }

    @Test func schemeIsCaseInsensitive() throws {
        let url = try #require(URL(string: "CROCUS://test"))
        #expect(router.action(for: url) != nil)
    }

    @Test(arguments: ["insel://test", "https://example.com", "file:///tmp/x"])
    func rejectsOtherSchemes(_ string: String) throws {
        let url = try #require(URL(string: string))
        #expect(router.action(for: url) == nil)
    }
}
