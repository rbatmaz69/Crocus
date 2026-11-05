import Carbon.HIToolbox
import Testing
@testable import Crocus

@Suite struct KeyboardShortcutSpecTests {
    @Test func defaultIsControlOptionSpace() {
        let spec = KeyboardShortcutSpec.default
        #expect(spec.keyCode == UInt32(kVK_Space))
        #expect(spec.modifiers == [.control, .option])
        #expect(spec.displayString == "⌃⌥Space")
        #expect(spec.stringValue == "ctrl+opt+49")
    }

    @Test func roundTrip() {
        let spec = KeyboardShortcutSpec(keyCode: UInt32(kVK_ANSI_I), modifiers: [.option, .command])
        #expect(KeyboardShortcutSpec(string: spec.stringValue) == spec)
        #expect(spec.displayString == "⌥⌘I")
    }

    @Test(arguments: ["", "49", "ctrl+opt", "ctrl+bogus+49", "ctrl+opt+x"])
    func invalidStrings(_ string: String) {
        #expect(KeyboardShortcutSpec(string: string) == nil)
    }

    @Test func carbonModifiers() {
        let spec = KeyboardShortcutSpec(keyCode: 0, modifiers: [.control, .option, .shift, .command])
        #expect(spec.carbonModifiers == UInt32(controlKey | optionKey | shiftKey | cmdKey))
        #expect(KeyboardShortcutSpec.default.carbonModifiers == UInt32(controlKey | optionKey))
    }

    @Test func settingsFallBackToDefault() {
        let defaults = UserDefaults(suiteName: "KeyboardShortcutSpecTests")!
        defaults.removePersistentDomain(forName: "KeyboardShortcutSpecTests")
        #expect(AppSettings.globalShortcut(in: defaults) == .default)
        defaults.set("garbage", forKey: AppSettings.Key.globalShortcut)
        #expect(AppSettings.globalShortcut(in: defaults) == .default)
        defaults.set("", forKey: AppSettings.Key.globalShortcut)
        #expect(AppSettings.globalShortcut(in: defaults) == nil)
    }
}
