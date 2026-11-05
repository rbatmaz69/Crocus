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
                var fields = try fields(from: parameters, symbolExists: symbolExists)
                guard fields.title != nil else { throw LiveActivityError.missingParameter("title") }
                fields.progress = fields.progress ?? .indeterminate
                return .success(.start(id: id, fields: fields))
            case "update":
                return .success(.update(id: id, fields: try fields(from: parameters, symbolExists: symbolExists)))
            case "end":
                let result = try LiveActivityValidation.result(parameters["result"])
                let text = LiveActivityValidation.text(parameters["text"], maxLength: LiveActivityValidation.maxStatusLength)
                return .success(.end(id: id, result: result, text: text))
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
        typealias V = LiveActivityValidation
        let action = V.actionURL(parameters["action"]).map {
            LiveActivityAction(url: $0, title: V.text(parameters["actionTitle"], maxLength: V.maxActionTitleLength) ?? V.defaultActionTitle)
        }
        return LiveActivityFields(
            title: V.text(parameters["title"], maxLength: V.maxTitleLength),
            symbol: V.symbol(parameters["symbol"], exists: symbolExists),
            progress: try V.progress(parameters["progress"]),
            status: V.text(parameters["status"], maxLength: V.maxStatusLength),
            action: action,
            source: V.text(parameters["source"], maxLength: V.maxSourceLength)
        )
    }
}
