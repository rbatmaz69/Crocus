import Foundation

/// How a Live Activity ended; shown for 3 s before it disappears.
enum LiveActivityResult: String, CaseIterable, Sendable {
    case success
    case failure
    case cancelled
}

/// Progress of a Live Activity: a value 0–1, or indeterminate (spinner).
enum LiveActivityProgress: Equatable, Sendable {
    case indeterminate
    case value(Double)
}

/// The optional action button of a Live Activity.
struct LiveActivityAction: Equatable, Sendable {
    let url: URL
    let title: String
}

/// Fields a start or update may set. `nil` means "not given": a start uses a
/// default, an update keeps the current value.
struct LiveActivityFields: Equatable, Sendable {
    var title: String?
    var symbol: String?
    var progress: LiveActivityProgress?
    var status: String?
    var action: LiveActivityAction?
    var source: String?
}

/// A validated request from any source: the URL scheme or the App Intents.
enum LiveActivityCommand: Equatable, Sendable {
    case start(id: String, fields: LiveActivityFields)
    case update(id: String, fields: LiveActivityFields)
    case end(id: String, result: LiveActivityResult, text: String?)

    var id: String {
        switch self {
        case .start(let id, _), .update(let id, _), .end(let id, _, _): id
        }
    }
}

enum LiveActivityError: Error, Equatable, CustomStringConvertible {
    case unknownCommand(String)
    case missingParameter(String)
    case invalidID(String)
    case invalidProgress(String)
    case invalidResult(String)
    /// Only from App Intents; the URL scheme ignores unknown ids silently.
    case notRunning(String)

    var description: String {
        switch self {
        case .unknownCommand(let command): "unknown command '\(command)' (use start, update or end)"
        case .missingParameter(let name): "missing parameter '\(name)'"
        case .invalidID(let id): "invalid id '\(id)' (1–64 characters: letters, digits, . _ -)"
        case .invalidProgress(let value): "invalid progress '\(value)' (a number from 0 to 1, or empty)"
        case .invalidResult(let value): "invalid result '\(value)' (success, failure or cancelled)"
        case .notRunning(let id): "activity '\(id)' is not running"
        }
    }
}

/// Input rules for Live Activities. Untrusted input from any app or script:
/// ids are strict, texts are cleaned and shortened rather than rejected,
/// unknown symbols fall back, and only web and file links are opened.
enum LiveActivityValidation {
    static let maxIDLength = 64
    static let maxTitleLength = 60
    static let maxStatusLength = 120
    static let maxSourceLength = 40
    static let maxActionTitleLength = 24
    static let maxSymbolLength = 64
    static let fallbackSymbol = "app.badge"
    static let defaultSource = "Live Activity"
    static let defaultActionTitle = "Open"
    static let allowedActionSchemes: Set<String> = ["https", "http", "file"]

    private static let idCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    private static let symbolCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.")

    static func id(_ raw: String?) throws -> String {
        guard let raw else { throw LiveActivityError.missingParameter("id") }
        guard (1...maxIDLength).contains(raw.count),
              raw.unicodeScalars.allSatisfy(idCharacters.contains)
        else { throw LiveActivityError.invalidID(raw) }
        return raw
    }

    /// Strips control characters, trims, shortens with "…". Empty → `nil`.
    static func text(_ raw: String?, maxLength: Int) -> String? {
        guard let raw else { return nil }
        let cleaned = String(String.UnicodeScalarView(raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        guard cleaned.count > maxLength else { return cleaned }
        return String(cleaned.prefix(maxLength - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Valid SF Symbol name, or the fallback symbol. `nil` when not given.
    static func symbol(_ raw: String?, exists: (String) -> Bool) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        guard raw.count <= maxSymbolLength,
              raw.unicodeScalars.allSatisfy(symbolCharacters.contains),
              exists(raw)
        else { return fallbackSymbol }
        return raw
    }

    /// `nil` when not given; empty = indeterminate; numbers are clamped to 0–1.
    static func progress(_ raw: String?) throws -> LiveActivityProgress? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .indeterminate }
        guard let value = Double(trimmed), value.isFinite else { throw LiveActivityError.invalidProgress(raw) }
        return .value(min(max(value, 0), 1))
    }

    /// For typed sources (App Intents): `nil` when not given; clamped to 0–1;
    /// NaN and infinity are rejected.
    static func progress(number value: Double?) throws -> LiveActivityProgress? {
        guard let value else { return nil }
        guard value.isFinite else { throw LiveActivityError.invalidProgress(String(value)) }
        return .value(min(max(value, 0), 1))
    }

    /// Only https, http and file links; anything else is dropped.
    static func actionURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), let scheme = url.scheme?.lowercased(),
              allowedActionSchemes.contains(scheme)
        else { return nil }
        return url
    }

    static func result(_ raw: String?) throws -> LiveActivityResult {
        guard let raw, !raw.isEmpty else { return .success }
        guard let result = LiveActivityResult(rawValue: raw.lowercased()) else {
            throw LiveActivityError.invalidResult(raw)
        }
        return result
    }
}

/// Turns raw input from any source – the URL scheme or the App Intents (#12) –
/// into validated commands, so both follow exactly the same rules.
enum LiveActivityCommandBuilder {
    typealias V = LiveActivityValidation

    /// Validates the start/update values. Progress is already parsed by the
    /// source (text from a URL, a number from an intent).
    static func fields(
        title: String? = nil,
        symbol: String? = nil,
        progress: LiveActivityProgress? = nil,
        status: String? = nil,
        action: String? = nil,
        actionTitle: String? = nil,
        source: String? = nil,
        symbolExists: (String) -> Bool
    ) -> LiveActivityFields {
        let action = V.actionURL(action).map {
            LiveActivityAction(url: $0, title: V.text(actionTitle, maxLength: V.maxActionTitleLength) ?? V.defaultActionTitle)
        }
        return LiveActivityFields(
            title: V.text(title, maxLength: V.maxTitleLength),
            symbol: V.symbol(symbol, exists: symbolExists),
            progress: progress,
            status: V.text(status, maxLength: V.maxStatusLength),
            action: action,
            source: V.text(source, maxLength: V.maxSourceLength)
        )
    }

    /// A start needs a title; without progress it shows a spinner.
    static func start(id: String?, fields: LiveActivityFields) throws -> LiveActivityCommand {
        let id = try V.id(id)
        guard fields.title != nil else { throw LiveActivityError.missingParameter("title") }
        var fields = fields
        fields.progress = fields.progress ?? .indeterminate
        return .start(id: id, fields: fields)
    }

    static func update(id: String?, fields: LiveActivityFields) throws -> LiveActivityCommand {
        .update(id: try V.id(id), fields: fields)
    }

    static func end(id: String?, result: LiveActivityResult, text: String?) throws -> LiveActivityCommand {
        .end(id: try V.id(id), result: result, text: V.text(text, maxLength: V.maxStatusLength))
    }
}
