import AppIntents

/// Start Activity · Update Progress · End Activity – the Live Activities
/// platform (#11) in Shortcuts, Spotlight and Siri. Same rules as the
/// `crocus://` URL scheme; see docs/live-activities.md.
struct StartLiveActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Activity"
    static let description = IntentDescription(
        "Shows a new Live Activity in the Crocus island. Returns the activity, so Update Progress and End Activity can use it.",
        categoryName: "Live Activities"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Symbol", description: "An SF Symbol name, e.g. hammer. Unknown names show app.badge.")
    var symbol: String?

    @Parameter(title: "Progress", description: "From 0 to 1. Empty shows a spinner.")
    var progress: Double?

    @Parameter(title: "Status")
    var status: String?

    @Parameter(title: "Action", description: "A link for the button: https, http or file.")
    var action: URL?

    @Parameter(title: "Button Title", description: "Defaults to Open.")
    var actionTitle: String?

    @Parameter(title: "Source", description: "Shown above the title. Defaults to Shortcuts.")
    var source: String?

    @Parameter(
        title: "Identifier",
        description: "Letters, digits, . _ - (up to 64). Starting an identifier that is already shown restarts it. Empty creates a new one."
    )
    var identifier: String?

    @Dependency private var manager: LiveActivityManager

    static var parameterSummary: some ParameterSummary {
        Summary("Start activity with title \(\.$title) and symbol \(\.$symbol)") {
            \.$progress
            \.$status
            \.$action
            \.$actionTitle
            \.$source
            \.$identifier
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<LiveActivityEntity> {
        let activity = try LiveActivityIntentHandler(manager: manager).start(
            title: title, symbol: symbol, progress: progress, status: status,
            action: action, actionTitle: actionTitle, source: source, identifier: identifier
        )
        return .result(value: activity)
    }
}

struct UpdateLiveActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Progress"
    static let description = IntentDescription(
        "Sets the progress (0–1) and status of a running activity.",
        categoryName: "Live Activities"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Activity")
    var activity: LiveActivityEntity

    @Parameter(title: "Progress", description: "From 0 to 1. Empty keeps the current progress.")
    var progress: Double?

    @Parameter(title: "Status")
    var status: String?

    @Dependency private var manager: LiveActivityManager

    static var parameterSummary: some ParameterSummary {
        Summary("Update progress of \(\.$activity) to \(\.$progress) with status \(\.$status)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<LiveActivityEntity> {
        let updated = try LiveActivityIntentHandler(manager: manager).update(id: activity.id, progress: progress, status: status)
        return .result(value: updated)
    }
}

struct EndLiveActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "End Activity"
    static let description = IntentDescription(
        "Shows the result for 3 seconds, then the activity disappears.",
        categoryName: "Live Activities"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Activity")
    var activity: LiveActivityEntity

    @Parameter(title: "Result", default: .success)
    var result: LiveActivityResult

    @Parameter(title: "Text")
    var text: String?

    @Dependency private var manager: LiveActivityManager

    static var parameterSummary: some ParameterSummary {
        Summary("End \(\.$activity) as \(\.$result) with text \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try LiveActivityIntentHandler(manager: manager).end(id: activity.id, result: result, text: text)
        return .result()
    }
}

extension LiveActivityResult: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Result"
    static let caseDisplayRepresentations: [LiveActivityResult: DisplayRepresentation] = [
        .success: "Success",
        .failure: "Failed",
        .cancelled: "Cancelled",
    ]
}

/// Errors show up in Shortcuts with this text.
extension LiveActivityError: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        "\(description.prefix(1).uppercased() + description.dropFirst())."
    }
}
