import Foundation

/// What the three App Intents do, separate from their AppIntents wrappers so
/// it can be tested. Builds the same `LiveActivityCommand`s as the URL scheme
/// and hands them to the same manager.
@MainActor
struct LiveActivityIntentHandler {
    /// Shown in the expanded header when a shortcut doesn't set a source.
    static let defaultSource = "Shortcuts"

    let manager: LiveActivityManager
    var symbolExists: (String) -> Bool = LiveActivityURLParser.systemSymbolExists
    var makeID: () -> String = Self.generatedID

    /// For shortcuts that leave the identifier empty: valid and unique.
    nonisolated static func generatedID() -> String {
        "shortcut-" + UUID().uuidString.prefix(8).lowercased()
    }

    func start(
        title: String,
        symbol: String? = nil,
        progress: Double? = nil,
        status: String? = nil,
        action: URL? = nil,
        actionTitle: String? = nil,
        source: String? = nil,
        identifier: String? = nil
    ) throws -> LiveActivityEntity {
        let id = identifier.flatMap { $0.isEmpty ? nil : $0 } ?? makeID()
        var fields = LiveActivityCommandBuilder.fields(
            title: title,
            symbol: symbol,
            progress: try LiveActivityValidation.progress(number: progress),
            status: status,
            action: action?.absoluteString,
            actionTitle: actionTitle,
            source: source,
            symbolExists: symbolExists
        )
        fields.source = fields.source ?? Self.defaultSource
        let command = try LiveActivityCommandBuilder.start(id: id, fields: fields)
        manager.handle(command)
        return try entity(for: command.id)
    }

    /// Empty progress keeps the current value (a shortcut can't tell "empty"
    /// from "not set"); the URL scheme's `progress=` switches to a spinner.
    func update(id: String, progress: Double? = nil, status: String? = nil) throws -> LiveActivityEntity {
        let fields = LiveActivityCommandBuilder.fields(
            progress: try LiveActivityValidation.progress(number: progress),
            status: status,
            symbolExists: symbolExists
        )
        let command = try LiveActivityCommandBuilder.update(id: id, fields: fields)
        try requireRunning(command.id)
        manager.handle(command)
        return try entity(for: command.id)
    }

    func end(id: String, result: LiveActivityResult, text: String? = nil) throws {
        let command = try LiveActivityCommandBuilder.end(id: id, result: result, text: text)
        try requireRunning(command.id)
        manager.handle(command)
    }

    /// The URL scheme ignores unknown or ended ids silently; a shortcut
    /// reports it, so the user sees why nothing happened.
    private func requireRunning(_ id: String) throws {
        guard manager.activities[id]?.state.isRunning == true else { throw LiveActivityError.notRunning(id) }
    }

    private func entity(for id: String) throws -> LiveActivityEntity {
        guard let activity = manager.activities[id] else { throw LiveActivityError.notRunning(id) }
        return LiveActivityEntity(activity.state)
    }
}
