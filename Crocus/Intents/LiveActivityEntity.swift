import AppIntents

/// A Live Activity as Shortcuts sees it: "Start Activity" returns one, and
/// "Update Progress" and "End Activity" take it, so a shortcut can pass the
/// variable along instead of repeating the identifier.
struct LiveActivityEntity: AppEntity, Equatable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Activity"
    static let defaultQuery = LiveActivityEntityQuery()

    /// The activity's id – the same as `id=` in the URL scheme.
    let id: String
    let title: String
    let symbol: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(id)", image: .init(systemName: symbol))
    }
}

extension LiveActivityEntity {
    init(_ state: LiveActivityState) {
        self.init(id: state.id, title: state.title, symbol: state.symbol)
    }

    /// Stands in for an id that isn't running (anymore), e.g. a variable from
    /// an earlier run. Update and End then report "not running" instead of
    /// Shortcuts failing to resolve the parameter.
    init(placeholderFor id: String) {
        self.init(id: id, title: id, symbol: LiveActivityValidation.fallbackSymbol)
    }
}

struct LiveActivityEntityQuery: EntityQuery {
    @Dependency private var manager: LiveActivityManager

    @MainActor
    func entities(for identifiers: [LiveActivityEntity.ID]) async throws -> [LiveActivityEntity] {
        Self.entities(for: identifiers, in: manager)
    }

    /// The running activities, to pick one in the Shortcuts editor.
    @MainActor
    func suggestedEntities() async throws -> [LiveActivityEntity] {
        Self.suggestedEntities(in: manager)
    }

    @MainActor
    static func entities(for identifiers: [String], in manager: LiveActivityManager) -> [LiveActivityEntity] {
        identifiers.compactMap { id in
            if let activity = manager.activities[id] { return LiveActivityEntity(activity.state) }
            // Only well-formed ids; anything else can't have come from Crocus.
            return (try? LiveActivityValidation.id(id)).map(LiveActivityEntity.init(placeholderFor:))
        }
    }

    @MainActor
    static func suggestedEntities(in manager: LiveActivityManager) -> [LiveActivityEntity] {
        manager.activities.values
            .filter(\.state.isRunning)
            .sorted { $0.state.startedAt > $1.state.startedAt }
            .map { LiveActivityEntity($0.state) }
    }
}
