import Foundation

/// Finds a video call link in an event's URL, location and notes.
enum VideoCallLink {
    enum Provider: String, CaseIterable, Sendable {
        case zoom, meet, teams, faceTime, webex

        var name: String {
            switch self {
            case .zoom: "Zoom"
            case .meet: "Google Meet"
            case .teams: "Microsoft Teams"
            case .faceTime: "FaceTime"
            case .webex: "Webex"
            }
        }
    }

    /// The meeting link's provider; `nil` for anything else (also a bare
    /// `zoom.us` or a plain `http` link).
    static func provider(for url: URL) -> Provider? {
        guard url.scheme?.lowercased() == "https", let host = url.host()?.lowercased() else { return nil }
        let path = url.path().lowercased()
        func on(_ domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }

        if on("zoom.us"), ["/j/", "/my/", "/s/", "/w/"].contains(where: path.hasPrefix) { return .zoom }
        if host == "meet.google.com", path.range(of: #"^/[a-z]{3}-[a-z]{4}-[a-z]{3}"#, options: .regularExpression) != nil { return .meet }
        if host == "teams.microsoft.com", path.hasPrefix("/l/meetup-join/") { return .teams }
        if host == "teams.live.com", path.hasPrefix("/meet/") { return .teams }
        if host == "facetime.apple.com", path.hasPrefix("/join") { return .faceTime }
        if on("webex.com"), path.hasPrefix("/meet/") || path.hasPrefix("/join/") || path.contains("j.php") { return .webex }
        return nil
    }

    /// The first meeting link in the texts, in order.
    static func find(in texts: [String?]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                if let url = match.url, provider(for: url) != nil { return url }
            }
        }
        return nil
    }
}
