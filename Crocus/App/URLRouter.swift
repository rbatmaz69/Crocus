import Foundation
import os

/// What a `crocus://` URL asks the app to do.
enum CrocusURLAction: Equatable, Sendable {
    /// start / update / end a Live Activity (#11).
    case liveActivity(LiveActivityCommand)
    /// A crocus URL that couldn't be understood; the reason is logged.
    case invalid(String)
}

struct URLRouter: Sendable {
    static let scheme = "crocus"

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "URLRouter")

    var symbolExists: LiveActivityURLParser.SymbolCheck = LiveActivityURLParser.systemSymbolExists

    /// Parses a URL. Returns `nil` for any scheme other than `crocus`.
    func action(for url: URL) -> CrocusURLAction? {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        switch LiveActivityURLParser.parse(url, symbolExists: symbolExists) {
        case .success(let command): return .liveActivity(command)
        case .failure(let error): return .invalid(error.description)
        }
    }

    @discardableResult
    func handle(_ url: URL) -> CrocusURLAction? {
        guard let action = action(for: url) else {
            Self.logger.error("Rejected URL with unsupported scheme: \(url.absoluteString, privacy: .public)")
            return nil
        }
        if case .invalid(let reason) = action {
            Self.logger.error("Rejected \(url.absoluteString, privacy: .public): \(reason, privacy: .public)")
        } else {
            Self.logger.info("Received \(url.absoluteString, privacy: .public)")
        }
        return action
    }
}
