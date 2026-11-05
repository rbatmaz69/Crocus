import Foundation
import os

/// What a `crocus://` URL asks the app to do. Real actions are added with the
/// Live Activities platform (#11); for now every valid URL is `.unknown`.
enum CrocusURLAction: Equatable, Sendable {
    case unknown(host: String?, path: String)
}

struct URLRouter: Sendable {
    static let scheme = "crocus"

    private static let logger = Logger(subsystem: "com.rbatmaz69.crocus", category: "URLRouter")

    /// Parses a URL. Returns `nil` for any scheme other than `crocus`.
    func action(for url: URL) -> CrocusURLAction? {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        return .unknown(host: url.host(), path: url.path())
    }

    @discardableResult
    func handle(_ url: URL) -> CrocusURLAction? {
        guard let action = action(for: url) else {
            Self.logger.error("Rejected URL with unsupported scheme: \(url.absoluteString, privacy: .public)")
            return nil
        }
        Self.logger.info("Received crocus URL: \(url.absoluteString, privacy: .public)")
        return action
    }
}
