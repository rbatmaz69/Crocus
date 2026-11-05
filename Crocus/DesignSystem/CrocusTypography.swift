import SwiftUI

/// The user's text size setting ("Größe"); the setting UI lands in #27.
enum TextSizeAdjustment: CaseIterable, Sendable {
    case compact
    case standard
    case large

    var points: CGFloat {
        switch self {
        case .compact: -1
        case .standard: 0
        case .large: 2
        }
    }
}

struct TypeStyle: Equatable, Sendable {
    let size: CGFloat
    let weight: Font.Weight
    /// Tabular digits so times and percentages don't jitter while counting.
    let monospacedDigits: Bool

    /// Text in the compact island never goes below this size.
    static let compactMinimumSize: CGFloat = 13

    func size(for adjustment: TextSizeAdjustment, inCompactIsland: Bool = false) -> CGFloat {
        let adjusted = size + adjustment.points
        return inCompactIsland ? max(adjusted, Self.compactMinimumSize) : adjusted
    }

    func font(_ adjustment: TextSizeAdjustment = .standard, inCompactIsland: Bool = false) -> Font {
        let font = Font.system(size: size(for: adjustment, inCompactIsland: inCompactIsland), weight: weight)
        return monospacedDigits ? font.monospacedDigit() : font
    }
}

/// Type styles from the spec (`design/README.md`, board 01).
enum CrocusTypography {
    /// Big timer readout, e.g. "04:32".
    static let display = TypeStyle(size: 44, weight: .light, monospacedDigits: true)
    /// Big value, e.g. "40 %".
    static let value = TypeStyle(size: 22, weight: .semibold, monospacedDigits: true)
    /// Activity title, e.g. "Build läuft".
    static let title = TypeStyle(size: 15, weight: .semibold, monospacedDigits: false)
    /// Status line, e.g. "Kompiliere 128 von 320" (spec: 12–13 pt).
    static let status = TypeStyle(size: 13, weight: .regular, monospacedDigits: false)
    /// Small times, e.g. "1:24 / −2:27".
    static let caption = TypeStyle(size: 11, weight: .regular, monospacedDigits: true)
}
