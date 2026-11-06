import Foundation

/// Letterboxd non offre un'API pubblica (l'accesso va richiesto e viene
/// concesso raramente), quindi leggiamo le pagine pubbliche della watchlist:
/// `letterboxd.com/<utente>/watchlist/page/<n>/`.
/// Funziona per qualunque profilo con watchlist pubblica.
nonisolated enum LetterboxdError: LocalizedError {
    case invalidUsername
    case userNotFound
    case emptyOrPrivate
    case blocked
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .invalidUsername: String(localized: "Enter a valid username.")
        case .userNotFound: String(localized: "No Letterboxd user with this name.")
        case .emptyOrPrivate: String(localized: "The watchlist is empty or not public.")
        case .blocked: String(localized: "Letterboxd temporarily blocked the request. Try again shortly or import the CSV.")
        case .badResponse(let code): String(localized: "Unexpected response from Letterboxd (code \(code)).")
        }
    }
}

nonisolated struct LetterboxdWatchlist: Sendable {
    let username: String
    let displayName: String?
    let movies: [Movie]
}

nonisolated enum LetterboxdService {

    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    /// Accetta "nome", "@nome" o un link al profilo.
    static func normalizeUsername(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let range = value.range(of: "letterboxd.com/") {
            value = String(value[range.upperBound...])
            value = value.split(separator: "/").first.map(String.init) ?? ""
        }
        if value.hasPrefix("@") { value.removeFirst() }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard !value.isEmpty, value.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return value
    }

    static func fetchWatchlist(username raw: String) async throws -> LetterboxdWatchlist {
        guard let username = normalizeUsername(raw) else { throw LetterboxdError.invalidUsername }

        let firstPage = try await fetchPage(username: username, page: 1)
        let lastPage = lastPageNumber(in: firstPage)
        var pages: [Int: [ParsedFilm]] = [1: parseFilms(in: firstPage)]

        if lastPage > 1 {
            // Scarica le pagine rimanenti in parallelo (max 4 alla volta).
            try await withThrowingTaskGroup(of: (Int, [ParsedFilm]).self) { group in
                var next = 2
                func addNext() {
                    guard next <= lastPage else { return }
                    let page = next
                    next += 1
                    group.addTask { (page, parseFilms(in: try await fetchPage(username: username, page: page))) }
                }
                for _ in 0..<4 { addNext() }
                while let (page, films) = try await group.next() {
                    pages[page] = films
                    addNext()
                }
            }
        }

        // Le pagine sono ordinate dal film aggiunto più di recente.
        var seen = Set<String>()
        let films = (1...max(lastPage, 1)).flatMap { pages[$0] ?? [] }.filter { seen.insert($0.id).inserted }
        guard !films.isEmpty else { throw LetterboxdError.emptyOrPrivate }

        let movies = films.enumerated().map { index, film in
            Movie(id: film.id, title: film.title, year: film.year, slug: film.slug,
                  dateAdded: nil, addedIndex: films.count - index)
        }
        return LetterboxdWatchlist(username: username, displayName: displayName(in: firstPage), movies: movies)
    }

    // MARK: - Rete

    private static func fetchPage(username: String, page: Int) async throws -> String {
        let path = page == 1 ? "" : "page/\(page)/"
        let url = URL(string: "https://letterboxd.com/\(username)/watchlist/\(path)")!
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let html = String(decoding: data, as: UTF8.self)

        switch status {
        case 200: break
        case 404: throw LetterboxdError.userNotFound
        case 403, 429, 503: throw LetterboxdError.blocked
        default: throw LetterboxdError.badResponse(status)
        }
        if html.contains("<title>Just a moment...</title>") { throw LetterboxdError.blocked }
        return html
    }

    // MARK: - Parsing HTML

    private struct ParsedFilm: Sendable {
        let id: String
        let title: String
        let year: String
        let slug: String?
    }

    private static func parseFilms(in html: String) -> [ParsedFilm] {
        // Limitiamo il parsing alla griglia dei poster, ignorando le sidebar.
        var grid = Substring(html)
        if let start = html.range(of: "class=\"poster-grid\"") {
            grid = html[start.lowerBound...]
            if let end = grid.range(of: "class=\"pagination\"") { grid = grid[..<end.lowerBound] }
        }

        return grid.components(separatedBy: "data-item-name=\"").dropFirst().compactMap { chunk in
            guard let nameEnd = chunk.firstIndex(of: "\"") else { return nil }
            let fullName = decodeEntities(String(chunk[..<nameEnd]))
            let slug = chunk.firstMatch(of: #/data-item-slug="([^"]+)"/#).map { String($0.1) }
            guard let lid = chunk.firstMatch(of: #/&quot;lid&quot;:&quot;([A-Za-z0-9]+)&quot;/#).map({ String($0.1) })
            else { return nil }

            // "Solaris (1972)" -> titolo + anno
            var title = fullName
            var year = ""
            if let match = fullName.firstMatch(of: #/^(.*) \((\d{4})\)$/#) {
                title = String(match.1)
                year = String(match.2)
            }
            return ParsedFilm(id: "https://boxd.it/\(lid)", title: title, year: year, slug: slug)
        }
    }

    private static func lastPageNumber(in html: String) -> Int {
        html.matches(of: #/watchlist/page/(\d+)//#).compactMap { Int($0.1) }.max() ?? 1
    }

    private static func displayName(in html: String) -> String? {
        guard let match = html.firstMatch(of: #/<title>(?:&lrm;)?(.*?)’s Watchlist/#) else { return nil }
        return decodeEntities(String(match.1))
    }

    static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        var result = string
        let named = ["&amp;": "&", "&quot;": "\"", "&#039;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&lrm;": "", "&nbsp;": " "]
        for (entity, value) in named where entity != "&amp;" {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        result = result.replacing(#/&#(x?)([0-9A-Fa-f]+);/#) { match in
            let radix = match.1.isEmpty ? 10 : 16
            guard let code = UInt32(match.2, radix: radix), let scalar = Unicode.Scalar(code) else { return String(match.0) }
            return String(Character(scalar))
        }
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }
}
