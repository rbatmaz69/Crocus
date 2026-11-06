import AppIntents

/// Start Timer · Start Stopwatch · Control Timer – the built-in timer (#13)
/// in Shortcuts, Spotlight and Siri.
struct StartTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Timer"
    static let description = IntentDescription(
        "Starts the timer in the Crocus island. A timer that is already running is replaced.",
        categoryName: "Timer"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Duration", description: "From 1 second to 24 hours.", defaultUnit: .minutes, supportsNegativeNumbers: false)
    var duration: Measurement<UnitDuration>

    @Dependency private var manager: TimerManager

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$duration) timer")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try TimerIntentHandler(manager: manager).startTimer(seconds: duration.converted(to: .seconds).value)
        return .result()
    }
}

struct StartStopwatchIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Stopwatch"
    static let description = IntentDescription(
        "Starts the stopwatch in the Crocus island from zero.",
        categoryName: "Timer"
    )
    static let supportedModes: IntentModes = .background

    @Dependency private var manager: TimerManager

    @MainActor
    func perform() async throws -> some IntentResult {
        TimerIntentHandler(manager: manager).startStopwatch()
        return .result()
    }
}

struct ControlTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Control Timer"
    static let description = IntentDescription(
        "Pauses, resumes or stops the timer or the stopwatch.",
        categoryName: "Timer"
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Action", default: .pause)
    var action: TimerControlAction

    @Parameter(title: "Which", default: .timer)
    var kind: TimerState.Kind

    @Dependency private var manager: TimerManager

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$action) the \(\.$kind)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try TimerIntentHandler(manager: manager).control(action, kind)
        return .result()
    }
}

enum TimerControlAction: String, AppEnum {
    case pause
    case resume
    case stop

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Timer Action"
    static let caseDisplayRepresentations: [TimerControlAction: DisplayRepresentation] = [
        .pause: "Pause",
        .resume: "Resume",
        .stop: "Stop",
    ]
}

extension TimerState.Kind: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Timer"
    static let caseDisplayRepresentations: [TimerState.Kind: DisplayRepresentation] = [
        .timer: "Timer",
        .stopwatch: "Stopwatch",
    ]
}

enum TimerIntentError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    case invalidDuration
    case notRunning(TimerState.Kind)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidDuration: "The duration must be between 1 second and 24 hours."
        case .notRunning(.timer): "No timer is running."
        case .notRunning(.stopwatch): "No stopwatch is running."
        }
    }
}

/// What the timer intents do, testable without AppIntents.
@MainActor
struct TimerIntentHandler {
    let manager: TimerManager

    func startTimer(seconds: Double) throws {
        guard seconds.isFinite, TimerState.durationRange.contains(seconds) else { throw TimerIntentError.invalidDuration }
        manager.startTimer(duration: seconds)
    }

    func startStopwatch() {
        manager.startStopwatch()
    }

    func control(_ action: TimerControlAction, _ kind: TimerState.Kind) throws {
        guard manager.state(kind) != nil else { throw TimerIntentError.notRunning(kind) }
        switch action {
        case .pause: manager.pause(kind)
        case .resume: manager.resume(kind)
        case .stop: manager.stop(kind)
        }
    }
}
