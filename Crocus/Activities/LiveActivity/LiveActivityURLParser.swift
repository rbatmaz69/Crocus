import AppKit

/// Turns a `crocus://` URL into a validated Live Activity command:
///
///     crocus://start?id=build&title=Build&symbol=hammer&progress=0.4&status=…
///     crocus://update?id=build&progress=0.6&status=…
///     crocus://end?id=build&result=success
///
/// Optional on start/update: `symbol`, `progress` (empty = indeterminate),
/// `status`, `source`, `action` (https/http/file URL) and `actionTitle`.
/// On end: `result` (success | failure | cancelled) and `text`.
enum LiveActivityURLParser {
    /// Whether an SF Symbol exists; injectable for tests.
    typealias SymbolCheck = @Sendable (String) -> Bool

    static let systemSymbolExists: SymbolCheck = { name in
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }

    static func parse(_ url: URL, symbolExists: SymbolCheck = systemSymbolExists) -> Result<LiveActivityCommand, LiveActivityError> {
        let command = (url.host() ?? "").lowercased()
        var parameters: [String: String] = [:]
        for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
            parameters[item.name] = item.value ?? "" // the last one wins
        }

        do {
            let id = try LiveActivityValidation.id(parameters["id"])
            switch command {
            case "start":
                return .success(try LiveActivityCommandBuilder.start(id: id, fields: try fields(from: parameters, symbolExists: symbolExists)))
            case "update":
                return .success(try LiveActivityCommandBuilder.update(id: id, fields: try fields(from: parameters, symbolExists: symbolExists)))
            case "end":
                let result = try LiveActivityValidation.result(parameters["result"])
                return .success(try LiveActivityCommandBuilder.end(id: id, result: result, text: parameters["text"]))
            default:
                throw LiveActivityError.unknownCommand(command)
            }
        } catch let error as LiveActivityError {
            // An unknown command is the more useful message, even without an id.
            if !["start", "update", "end"].contains(command) { return .failure(.unknownCommand(command)) }
            return .failure(error)
        } catch {
            return .failure(.unknownCommand(command))
        }
    }

    private static func fields(from parameters: [String: String], symbolExists: SymbolCheck) throws -> LiveActivityFields {
        LiveActivityCommandBuilder.fields(
            title: parameters["title"],
            symbol: parameters["symbol"],
            progress: try LiveActivityValidation.progress(parameters["progress"]),
            status: parameters["status"],
            action: parameters["action"],
            actionTitle: parameters["actionTitle"],
            source: parameters["source"],
            symbolExists: symbolExists
        )
    }
}
