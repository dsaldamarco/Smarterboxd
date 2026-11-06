import SwiftUI

/// Un film della watchlist.
/// `id` è l'URL breve di Letterboxd (es. "https://boxd.it/2a2Y"): è lo stesso
/// sia nel CSV esportato sia nelle pagine della watchlist, quindi classifica e
/// film nascosti restano validi qualunque sia la fonte dei dati.
nonisolated struct Movie: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let year: String
    var slug: String?
    /// Data di aggiunta (formato "yyyy-MM-dd"); disponibile solo dal CSV.
    var dateAdded: String?
    /// Più alto = aggiunto più di recente. Serve per ordinare.
    var addedIndex: Int

    var yearValue: Int { Int(year) ?? 0 }

    var letterboxdURL: URL? {
        if let slug { return URL(string: "https://letterboxd.com/film/\(slug)/") }
        return URL(string: id)
    }

    var formattedDateAdded: String? {
        guard let dateAdded,
              let date = try? Date(dateAdded, strategy: .iso8601.year().month().day())
        else { return nil }
        return date.formatted(date: .long, time: .omitted)
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case addedNewest, addedOldest, releaseNewest, releaseOldest, title

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .addedNewest: "Recently added"
        case .addedOldest: "First added"
        case .releaseNewest: "Newest release"
        case .releaseOldest: "Oldest release"
        case .title: "Title (A–Z)"
        }
    }

    func sorted(_ movies: [Movie]) -> [Movie] {
        switch self {
        case .addedNewest: movies.sorted { $0.addedIndex > $1.addedIndex }
        case .addedOldest: movies.sorted { $0.addedIndex < $1.addedIndex }
        case .releaseNewest: movies.sorted { ($0.yearValue, $0.addedIndex) > ($1.yearValue, $1.addedIndex) }
        case .releaseOldest: movies.sorted { ($0.yearValue, $0.addedIndex) < ($1.yearValue, $1.addedIndex) }
        case .title: movies.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }
}
