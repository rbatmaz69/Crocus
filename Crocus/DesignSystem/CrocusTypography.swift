import SwiftUI

/// The user's text size setting (Settings › Appearance › Size).
enum TextSizeAdjustment: String, CaseIterable, Identifiable, Sendable {
    case compact
    case standard
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: "Compact"
        case .standard: "Standard"
        case .large: "Large"
        }
    }

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
    /// Button titles, e.g. "Join".
    static let button = TypeStyle(size: 13, weight: .semibold, monospacedDigits: false)
    /// The expanded header, e.g. "Activities · 2 of 3".
    static let header = TypeStyle(size: 11, weight: .regular, monospacedDigits: false)
}

extension EnvironmentValues {
    /// The text size setting, set at the island's root.
    @Entry var islandTextSize: TextSizeAdjustment = .standard
}

/// A spec type style at the user's text size.
private struct IslandFont: ViewModifier {
    let style: TypeStyle
    let inCompactIsland: Bool
    @Environment(\.islandTextSize) private var textSize

    func body(content: Content) -> some View {
        content.font(style.font(textSize, inCompactIsland: inCompactIsland))
    }
}

extension View {
    func islandFont(_ style: TypeStyle, inCompactIsland: Bool = false) -> some View {
        modifier(IslandFont(style: style, inCompactIsland: inCompactIsland))
    }
}
