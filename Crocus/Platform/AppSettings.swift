import Foundation

/// User defaults keys and defaults. The settings UI lands in #27; until then
/// the defaults apply (or set them with `defaults write com.rbatmaz69.crocus …`).
enum AppSettings {
    enum Key {
        static let hideDuringFullScreenVideo = "hideDuringFullScreenVideo"
    }

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            Key.hideDuringFullScreenVideo: true,
        ])
    }

    static func hideDuringFullScreenVideo(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: Key.hideDuringFullScreenVideo)
    }
}
