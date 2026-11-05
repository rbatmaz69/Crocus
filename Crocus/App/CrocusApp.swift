import SwiftUI

/// Crocus runs as a menu bar agent (`LSUIElement = YES`): no Dock icon and no
/// main window. The island overlay itself is added in later issues (#3).
@main
struct CrocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Crocus", systemImage: "capsule.fill") {
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit Crocus") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsPlaceholderView()
        }
    }
}

/// Placeholder until the real settings window lands (#27).
private struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "capsule.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Crocus")
                .font(.title2.weight(.semibold))
            Text("Settings are coming soon.")
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 360)
    }
}
