import AppKit
import CoreServices
import os

/// Talks to the players. Only ever to running ones: an Apple Event to a
/// player that isn't running would launch it.
@MainActor
protocol PlayerBridge {
    func isRunning(_ player: MusicPlayer) -> Bool
    /// Asks the user (system dialog) when `askIfNeeded` and not yet decided.
    func permission(_ player: MusicPlayer, askIfNeeded: Bool) async -> PlayerPermission
    /// Playback position in seconds.
    func position(_ player: MusicPlayer) -> TimeInterval?
    /// Spotify only: the cover's URL.
    func artworkURL(_ player: MusicPlayer) -> URL?
    func send(_ command: PlayerCommand, to player: MusicPlayer)
    func open(_ player: MusicPlayer)
    func isInstalled(_ player: MusicPlayer) -> Bool
    /// Starts the player without bringing it forward, so macOS can ask for
    /// permission (it only asks about running apps). `false` if it didn't start.
    func launchInBackground(_ player: MusicPlayer) async -> Bool
}

/// The real bridge: short AppleScripts via `NSAppleScript` (main thread),
/// permission checks via `AEDeterminePermissionToAutomateTarget`.
struct AppleScriptPlayerBridge: PlayerBridge {
    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "NowPlaying")

    func isRunning(_ player: MusicPlayer) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleID).isEmpty
    }

    func isInstalled(_ player: MusicPlayer) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) != nil
    }

    func launchInBackground(_ player: MusicPlayer) async -> Bool {
        if isRunning(player) { return true }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        guard (try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)) != nil else { return false }
        // Give it a moment to answer Apple Events.
        for _ in 0..<20 where !isRunning(player) {
            try? await Task.sleep(for: .milliseconds(100))
        }
        try? await Task.sleep(for: .milliseconds(500))
        return isRunning(player)
    }

    func permission(_ player: MusicPlayer, askIfNeeded: Bool) async -> PlayerPermission {
        guard isRunning(player) else { return .unavailable }
        let bundleID = player.bundleID
        // Blocks while the system dialog is up, so off the main thread.
        let status = await Task.detached { Self.determinePermission(bundleID: bundleID, ask: askIfNeeded) }.value
        switch status {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(errAEEventWouldRequireUserConsent): return .notDetermined
        default: return .unavailable // e.g. procNotFound: not running (any more)
        }
    }

    func position(_ player: MusicPlayer) -> TimeInterval? {
        run("return player position", on: player)?.doubleValue
    }

    func artworkURL(_ player: MusicPlayer) -> URL? {
        guard player == .spotify,
              let string = run("return artwork url of current track", on: player)?.stringValue,
              let url = URL(string: string), url.scheme == "https"
        else { return nil }
        return url
    }

    func send(_ command: PlayerCommand, to player: MusicPlayer) {
        _ = run(command.appleScript, on: player)
    }

    func open(_ player: MusicPlayer) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Runs one statement in a `tell` block with a 2 s timeout.
    private func run(_ statement: String, on player: MusicPlayer) -> NSAppleEventDescriptor? {
        guard isRunning(player) else { return nil }
        let source = """
        with timeout of 2 seconds
            tell application id "\(player.bundleID)" to \(statement)
        end timeout
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorBriefMessage] as? String ?? "unknown error"
            Self.logger.error("\(player.displayName, privacy: .public) [\(statement, privacy: .public)]: \(message, privacy: .public)")
        }
        return result
    }

    nonisolated private static func determinePermission(bundleID: String, ask: Bool) -> OSStatus {
        var target = AEAddressDesc()
        return bundleID.withCString { pointer in
            guard AECreateDesc(typeApplicationBundleID, pointer, strlen(pointer), &target) == noErr else { return OSStatus(procNotFound) }
            defer { AEDisposeDesc(&target) }
            return AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, ask)
        }
    }
}
