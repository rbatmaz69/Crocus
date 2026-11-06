import Foundation

/// Covers for the Music app: the sandbox doesn't let Crocus read Music's
/// artwork, so it asks Apple's public iTunes Search API (no account, no
/// key) by artist and title. Only an exact match is used – a fuzzy search
/// easily finds another artist's album – so songs that aren't in the store
/// keep the placeholder.
enum ITunesArtwork {
    /// Cover size requested from Apple's image server.
    static let size = 600

    static func searchURL(title: String, artist: String, country: String) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: "\(artist) \(title)"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "country", value: country),
        ]
        return components?.url
    }

    /// The user's store, e.g. "DE"; "US" if unknown.
    static var country: String {
        Locale.current.region?.identifier ?? "US"
    }

    /// The cover of the result whose artist and title match exactly
    /// (ignoring case and accents); one from the same album first.
    static func artworkURL(in data: Data, title: String, artist: String, album: String?) -> URL? {
        struct Response: Decodable {
            struct Result: Decodable {
                let artistName: String?
                let trackName: String?
                let collectionName: String?
                let artworkUrl100: String?
            }
            let results: [Result]
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else { return nil }
        let matches = response.results.filter {
            normalized($0.artistName) == normalized(artist) && normalized($0.trackName) == normalized(title) && $0.artworkUrl100 != nil
        }
        let best = matches.first { normalized($0.collectionName) == normalized(album) } ?? matches.first
        guard let small = best?.artworkUrl100 else { return nil }
        let large = small.replacingOccurrences(of: "100x100bb", with: "\(size)x\(size)bb")
        guard let url = URL(string: large), url.scheme == "https" else { return nil }
        return url
    }

    private static func normalized(_ string: String?) -> String {
        (string ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
