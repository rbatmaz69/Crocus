import Foundation
import Testing
@testable import Crocus

@Suite struct LiveActivityURLParserTests {
    func parse(_ string: String, symbols: Set<String> = ["hammer", "arrow.up.circle"]) -> Result<LiveActivityCommand, LiveActivityError> {
        LiveActivityURLParser.parse(URL(string: string)!, symbolExists: { symbols.contains($0) })
    }

    @Test func issueExampleStart() {
        let result = parse("crocus://start?id=build&title=Build&symbol=hammer&progress=0.4&status=128%20of%20320")
        let expected = LiveActivityFields(title: "Build", symbol: "hammer", progress: .value(0.4), status: "128 of 320")
        #expect(result == .success(.start(id: "build", fields: expected)))
    }

    @Test func issueExampleUpdate() {
        let result = parse("crocus://update?id=build&progress=0.6&status=done%20soon")
        #expect(result == .success(.update(id: "build", fields: LiveActivityFields(progress: .value(0.6), status: "done soon"))))
    }

    @Test func issueExampleEnd() {
        #expect(parse("crocus://end?id=build&result=success") == .success(.end(id: "build", result: .success, text: nil)))
        #expect(parse("crocus://end?id=build") == .success(.end(id: "build", result: .success, text: nil)))
        #expect(parse("crocus://end?id=build&result=cancelled&text=Stopped") == .success(.end(id: "build", result: .cancelled, text: "Stopped")))
    }

    @Test func startWithoutProgressIsIndeterminate() {
        guard case .success(.start(_, let fields)) = parse("crocus://start?id=a&title=A") else {
            Issue.record("expected start")
            return
        }
        #expect(fields.progress == .indeterminate)
        #expect(fields.symbol == nil)
    }

    @Test func emptyProgressIsIndeterminate() {
        #expect(parse("crocus://update?id=a&progress=") == .success(.update(id: "a", fields: LiveActivityFields(progress: .indeterminate))))
    }

    @Test func updateWithoutProgressKeepsIt() {
        #expect(parse("crocus://update?id=a&status=x") == .success(.update(id: "a", fields: LiveActivityFields(status: "x"))))
    }

    @Test func actionWithTitle() {
        let result = parse("crocus://start?id=a&title=A&action=file:///tmp/build.log&actionTitle=Open%20Log")
        guard case .success(.start(_, let fields)) = result else {
            Issue.record("expected start")
            return
        }
        #expect(fields.action == LiveActivityAction(url: URL(string: "file:///tmp/build.log")!, title: "Open Log"))
    }

    @Test func lastDuplicateWins() {
        #expect(parse("crocus://update?id=a&progress=0.1&progress=0.9") == .success(.update(id: "a", fields: LiveActivityFields(progress: .value(0.9)))))
    }

    @Test func missingID() {
        #expect(parse("crocus://update?progress=0.5") == .failure(.missingParameter("id")))
    }

    @Test func missingTitleOnStart() {
        #expect(parse("crocus://start?id=a") == .failure(.missingParameter("title")))
    }

    @Test func unknownCommand() {
        #expect(parse("crocus://explode?id=a") == .failure(.unknownCommand("explode")))
        #expect(parse("crocus://explode") == .failure(.unknownCommand("explode")))
    }

    @Test func invalidValues() {
        #expect(parse("crocus://update?id=../x") == .failure(.invalidID("../x")))
        #expect(parse("crocus://update?id=a&progress=abc") == .failure(.invalidProgress("abc")))
        #expect(parse("crocus://end?id=a&result=maybe") == .failure(.invalidResult("maybe")))
    }
}
