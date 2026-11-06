import Foundation

/// Legge il file `watchlist.csv` dell'esportazione dati di Letterboxd
/// (Impostazioni › Dati › Esporta i tuoi dati).
/// Formato: Date,Name,Year,Letterboxd URI
nonisolated enum CSVParser {

    enum ParserError: LocalizedError {
        case unreadable
        case wrongFormat

        var errorDescription: String? {
            switch self {
            case .unreadable: String(localized: "Couldn’t read the file.")
            case .wrongFormat: String(localized: "This file doesn’t look like a Letterboxd watchlist.csv.")
            }
        }
    }

    static func loadMovies(from url: URL) throws -> [Movie] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else { throw ParserError.unreadable }
        return try parse(content)
    }

    static func parse(_ content: String) throws -> [Movie] {
        let rows = parseRows(content)
        guard let header = rows.first?.map({ $0.lowercased() }),
              let nameIndex = header.firstIndex(of: "name"),
              let uriIndex = header.firstIndex(of: "letterboxd uri")
        else { throw ParserError.wrongFormat }

        let dateIndex = header.firstIndex(of: "date")
        let yearIndex = header.firstIndex(of: "year")

        // Il CSV è in ordine cronologico: l'ultima riga è il film aggiunto più di recente.
        let movies = rows.dropFirst().enumerated().compactMap { index, row -> Movie? in
            guard row.count > max(nameIndex, uriIndex), !row[uriIndex].isEmpty else { return nil }
            func value(_ i: Int?) -> String? { i.flatMap { $0 < row.count ? row[$0] : nil } }
            return Movie(id: row[uriIndex], title: row[nameIndex], year: value(yearIndex) ?? "",
                         slug: nil, dateAdded: value(dateIndex), addedIndex: index + 1)
        }
        guard !movies.isEmpty else { throw ParserError.wrongFormat }
        return movies
    }

    /// Parser CSV (RFC 4180): gestisce virgole e virgolette dentro i campi.
    private static func parseRows(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = content.makeIterator()

        func handle(_ char: Character) {
            switch char {
            case "\"": inQuotes = true
            case ",": row.append(field); field = ""
            case "\n", "\r\n", "\r":
                row.append(field); field = ""
                if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                row = []
            default: field.append(char)
            }
        }


        while let char = iterator.next() {
            if inQuotes {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { field.append("\"") }
                        else {
                            inQuotes = false
                            handle(next)
                        }
                    } else { inQuotes = false }
                } else { field.append(char) }
            } else { handle(char) }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}
