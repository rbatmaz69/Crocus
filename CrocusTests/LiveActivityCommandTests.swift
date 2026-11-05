import Foundation
import Testing
@testable import Crocus

@Suite struct LiveActivityCommandTests {
    typealias V = LiveActivityValidation

    @Test(arguments: ["build", "a", "my-job_2.1", String(repeating: "x", count: 64)])
    func validIDs(_ id: String) throws {
        #expect(try V.id(id) == id)
    }

    @Test(arguments: ["", "../x", "a b", "ä", "a/b", String(repeating: "x", count: 65)])
    func invalidIDs(_ id: String) {
        #expect(throws: LiveActivityError.invalidID(id)) { try V.id(id) }
    }

    @Test func textIsCleanedAndShortened() {
        #expect(V.text("  Build \n", maxLength: 60) == "Build")
        #expect(V.text("a\u{0007}b\u{0000}c", maxLength: 60) == "abc")
        #expect(V.text("   ", maxLength: 60) == nil)
        #expect(V.text(nil, maxLength: 60) == nil)
        let long = V.text(String(repeating: "x", count: 100), maxLength: 60)
        #expect(long?.count == 60)
        #expect(long?.hasSuffix("…") == true)
    }

    @Test func progress() throws {
        #expect(try V.progress(nil) == nil)
        #expect(try V.progress("") == .indeterminate)
        #expect(try V.progress("0.4") == .value(0.4))
        #expect(try V.progress("1.7") == .value(1))
        #expect(try V.progress("-2") == .value(0))
        #expect(throws: LiveActivityError.invalidProgress("nan")) { try V.progress("nan") }
        #expect(throws: LiveActivityError.invalidProgress("inf")) { try V.progress("inf") }
        #expect(throws: LiveActivityError.invalidProgress("40%")) { try V.progress("40%") }
    }

    @Test func symbols() {
        let exists: (String) -> Bool = { $0 == "hammer" }
        #expect(V.symbol("hammer", exists: exists) == "hammer")
        #expect(V.symbol("not.a.symbol", exists: exists) == V.fallbackSymbol)
        #expect(V.symbol("Hammer", exists: { _ in true }) == V.fallbackSymbol)   // uppercase not allowed
        #expect(V.symbol("../etc", exists: { _ in true }) == V.fallbackSymbol)
        #expect(V.symbol(nil, exists: exists) == nil)
        #expect(V.symbol("", exists: exists) == nil)
    }

    @Test(arguments: ["https://example.com", "http://localhost:8080/x", "file:///Users/me/build.log", "HTTPS://EXAMPLE.COM"])
    func allowedActionURLs(_ string: String) {
        #expect(V.actionURL(string) != nil)
    }

    @Test(arguments: ["javascript:alert(1)", "crocus://start?id=x", "vscode://file/x", "x-apple.systempreferences:", "not a url", ""])
    func rejectedActionURLs(_ string: String) {
        #expect(V.actionURL(string) == nil)
    }

    @Test func results() throws {
        #expect(try V.result(nil) == .success)
        #expect(try V.result("FAILURE") == .failure)
        #expect(try V.result("cancelled") == .cancelled)
        #expect(throws: LiveActivityError.invalidResult("ok")) { try V.result("ok") }
    }
}
