import AppKit

/// Debug override for the pill outline.
enum PillOutlineOverride: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .light: "Light Wallpaper"
        case .dark: "Dark Wallpaper"
        }
    }
}

/// Tells whether the menu bar – and so the wallpaper right under the pill –
/// is light or dark. On Tahoe the menu bar is transparent and macOS tints its
/// items to match the wallpaper; Crocus' own status item window carries that
/// appearance. Falls back to the system appearance if it can't be found.
@MainActor
final class MenuBarAppearanceObserver {
    var onChange: ((Bool) -> Void)?
    private(set) var isDark: Bool = MenuBarAppearanceObserver.isDark(NSApp.effectiveAppearance)
    private(set) var source = "system"

    private var observedWindow: NSWindow?
    private var observation: NSKeyValueObservation?
    private var appObservation: NSKeyValueObservation?

    static func isDark(_ appearance: NSAppearance) -> Bool {
        let match = appearance.bestMatch(from: [.aqua, .darkAqua, .vibrantLight, .vibrantDark])
        return match == .darkAqua || match == .vibrantDark
    }

    /// Looks for the status item window (it appears once the menu bar extra
    /// is set up, so this is safe to call repeatedly).
    func attach() {
        if appObservation == nil {
            appObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.update() }
            }
        }
        guard observedWindow == nil,
              let window = NSApp.windows.first(where: { $0.className.contains("NSStatusBarWindow") })
        else { return }

        observedWindow = window
        source = "status item"
        observation = window.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.update() }
        }
    }

    private func update() {
        let appearance = observedWindow?.effectiveAppearance ?? NSApp.effectiveAppearance
        let dark = Self.isDark(appearance)
        guard dark != isDark else { return }
        isDark = dark
        onChange?(dark)
    }
}
