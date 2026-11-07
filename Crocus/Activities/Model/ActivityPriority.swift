import Foundation

/// Priority order of activity kinds: camera/microphone always first, the
/// rest in the user's order (or the default).
struct ActivityPriority: Equatable, Sendable {
    let order: [ActivityKind]

    static let `default` = ActivityPriority(storedOrder: [])

    /// Builds the order from stored raw values and cleans it up: unknown and
    /// duplicate values are dropped, camera/microphone is put back on top,
    /// missing kinds are appended in default order.
    init(storedOrder: [String]) {
        var rest: [ActivityKind] = []
        for raw in storedOrder {
            guard let kind = ActivityKind(rawValue: raw), !kind.isFixedOnTop, !rest.contains(kind) else { continue }
            rest.append(kind)
        }
        for kind in ActivityKind.allCases where !kind.isFixedOnTop && !rest.contains(kind) {
            rest.append(kind)
        }
        order = ActivityKind.allCases.filter(\.isFixedOnTop) + rest
    }

    /// The user-configurable part, for storing.
    var storedOrder: [String] {
        order.filter { !$0.isFixedOnTop }.map(\.rawValue)
    }

    /// The kinds the user can reorder (all but camera/microphone).
    var movable: [ActivityKind] { order.filter { !$0.isFixedOnTop } }

    /// Settings: rows dragged within the movable part (`List.onMove` offsets).
    func moving(fromOffsets source: IndexSet, toOffset destination: Int) -> ActivityPriority {
        var rest = movable
        let moved = source.sorted().map { rest[$0] }
        let insertAt = destination - source.filter { $0 < destination }.count
        rest.removeAll { moved.contains($0) }
        rest.insert(contentsOf: moved, at: min(max(insertAt, 0), rest.count))
        return ActivityPriority(storedOrder: rest.map(\.rawValue))
    }

    func rank(of kind: ActivityKind) -> Int {
        order.firstIndex(of: kind) ?? order.count
    }

    /// Highest priority first. Within a kind the older activity wins, so a
    /// running one isn't pushed aside by a newer one; the id makes it
    /// deterministic.
    func sorted(_ entries: [ActivityEntry]) -> [ActivityEntry] {
        entries.sorted { a, b in
            let ra = rank(of: a.kind), rb = rank(of: b.kind)
            if ra != rb { return ra < rb }
            if a.startedAt != b.startedAt { return a.startedAt < b.startedAt }
            return a.id < b.id
        }
    }
}
