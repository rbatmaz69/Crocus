/// What the island announces about power.
enum PowerEvent: Equatable, Sendable {
    /// Power adapter attached; the battery's level.
    case pluggedIn(level: Int)
    /// Battery dropped to 10 % or 5 %.
    case lowBattery(level: Int)
}

/// Turns battery snapshots into events, as a pure value:
/// - plugging in → `pluggedIn` (unplugging and "full" are silent)
/// - reaching 10 % and 5 % on battery → `lowBattery`, each once per
///   discharge; re-armed when plugged in, or once the level is back 2
///   points above, so a level wobbling around 10 % doesn't repeat it
/// - nothing for the state Crocus finds at launch
struct PowerEventDetector: Sendable {
    static let thresholds = [10, 5]
    static let rearmMargin = 2

    private(set) var last: PowerSnapshot?
    private(set) var warned: Set<Int> = []

    mutating func process(_ snapshot: PowerSnapshot?) -> [PowerEvent] {
        guard let snapshot else { return [] } // no battery
        defer { last = snapshot }

        guard let last else {
            // At launch: don't warn about levels already reached.
            if !snapshot.isOnAC { warned = Set(Self.thresholds.filter { snapshot.level <= $0 }) }
            return []
        }

        if snapshot.isOnAC {
            warned.removeAll()
            return last.isOnAC ? [] : [.pluggedIn(level: snapshot.level)]
        }

        warned = warned.filter { snapshot.level < $0 + Self.rearmMargin }
        let reached = Self.thresholds.filter { snapshot.level <= $0 && !warned.contains($0) }
        guard !reached.isEmpty else { return [] }
        // One warning even when several thresholds are passed at once.
        warned.formUnion(Self.thresholds.filter { snapshot.level <= $0 })
        return [.lowBattery(level: snapshot.level)]
    }
}
