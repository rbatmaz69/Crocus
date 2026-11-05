import SwiftUI

/// A color from the spec, stored as its sRGB hex value (`0xRRGGBB`).
struct ColorToken: Equatable, Sendable {
    let hex: UInt32

    var red: Double { Double((hex >> 16) & 0xFF) / 255 }
    var green: Double { Double((hex >> 8) & 0xFF) / 255 }
    var blue: Double { Double(hex & 0xFF) / 255 }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}

/// Colors from the spec (`design/README.md`, board 01).
///
/// The island is always black, so the dark variants are always used. The
/// accent colors map to system colors so they follow Increase Contrast; render
/// them inside `.islandEnvironment()` so the dark variant is picked.
enum CrocusColors {
    enum Spec {
        static let island = ColorToken(hex: 0x000000)
        static let primary = ColorToken(hex: 0xFFFFFF)
        static let secondary = ColorToken(hex: 0x98989D)
        /// Secondary text when "Increase Contrast" is on.
        static let secondaryHighContrast = ColorToken(hex: 0xC7C7CC)
        static let surface = ColorToken(hex: 0x2C2C2E)
        static let progress = ColorToken(hex: 0x0A84FF)
        /// Camera indicator and charging.
        static let positive = ColorToken(hex: 0x30D158)
        static let microphone = ColorToken(hex: 0xFF9F0A)
        static let lowBattery = ColorToken(hex: 0xFF453A)
    }

    static let island = Spec.island.color
    static let primary = Spec.primary.color
    static let secondary = Spec.secondary.color
    static let secondaryHighContrast = Spec.secondaryHighContrast.color
    static let surface = Spec.surface.color

    /// Only for fills (progress tracks, icons), never for text.
    static let progress = Color(nsColor: .systemBlue)
    static let positive = Color(nsColor: .systemGreen)
    static let microphone = Color(nsColor: .systemOrange)
    static let lowBattery = Color(nsColor: .systemRed)

    /// Opacity of the progress track; 35 % with Increase Contrast.
    static let progressTrackOpacity = 0.20
    static let progressTrackOpacityHighContrast = 0.35
}

extension View {
    /// Forces the dark appearance used everywhere on the black island.
    func islandEnvironment() -> some View {
        environment(\.colorScheme, .dark)
    }
}

/// Hairline outline around the floating pill so it stays defined on any
/// wallpaper: a dark hint on light backgrounds, a light hint on dark ones.
enum PillOutline {
    static let width: CGFloat = 0.5
    static let onLight = (token: CrocusColors.Spec.island, opacity: 0.12)
    static let onDark = (token: CrocusColors.Spec.primary, opacity: 0.08)

    static func spec(menuBarIsDark: Bool) -> (token: ColorToken, opacity: Double) {
        menuBarIsDark ? onDark : onLight
    }

    static func color(menuBarIsDark: Bool) -> Color {
        let spec = spec(menuBarIsDark: menuBarIsDark)
        return spec.token.color.opacity(spec.opacity)
    }
}
