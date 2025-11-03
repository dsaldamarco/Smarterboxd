import Foundation

// MARK: - 2. IL PARSER CSV

enum CSVParser {
    
    // Un errore personalizzato
    enum ParserError: Error {
        case fileNotFound(String)
        case parsingFailed(String)
    }
    
    // Funzione principale per caricare e analizzare il file
    static func loadMovies(from filename: String) throws -> [Movie] {
        
        // 1. Trova il file nel progetto
        guard let fileURL = Bundle.main.url(forResource: filename, withExtension: "csv") else {
            throw ParserError.fileNotFound("Impossibile trovare il file \(filename).csv nel progetto. Assicurati di averlo aggiunto al target.")
        }
        
        var movies: [Movie] = []
        let fileContent: String
        
        // 2. Leggi il contenuto del file
        do {
            fileContent = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw ParserError.parsingFailed("Impossibile leggere il file: \(error.localizedDescription)")
        }
        
        // 3. Dividi il file in righe
        let lines = fileContent.components(separatedBy: .newlines)
        
        // 4. Salta la prima riga (intestazioni) e analizza le altre
        for line in lines.dropFirst() {
            if line.isEmpty { continue } // Salta righe vuote
            
            // 5. Analizza una singola riga
            // Formato CSV: Date,Name,Year,Letterboxd URI
            if let movie = parse(line: line) {
                movies.append(movie)
            }
        }
        
        return movies
    }
    
    // Funzione helper che analizza una riga
    // usando un'Espressione Regolare (RegEx) per gestire le virgole
    private static func parse(line: String) -> Movie? {
        do {
            // Questa RegEx trova:
            // 1. Testo tra virgolette (es. "I, Tonya")
            // 2. O testo non separato da virgole (es. 2017)
            let regex = try NSRegularExpression(pattern: "\"(.*?)\"|([^,]+)")
            let results = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            
            let columns = results.map {
                let range = Range($0.range, in: line)!
                // Pulisce le virgolette e gli spazi bianchi
                return String(line[range])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }

            // Il CSV di Letterboxd ha questo formato:
            // 0: Date
            // 1: Name (Titolo)
            // 2: Year (Anno)
            // 3: Letterboxd URI (ID)
            
            if columns.count >= 4 {
                // Ora leggiamo tutte e 4 le colonne
                let date = columns[0]
                let title = columns[1]
                let year = columns[2]
                let id = columns[3]
                
                // Crea e restituisce il film (con posterURL nullo per ora)
                return Movie(id: id, title: title, year: year, dateAdded: date, posterURL: nil)
            }
            
        } catch {
            print("Errore RegEx: \(error)")
        }
        
        return nil // Parsing della riga fallito
    }
}
