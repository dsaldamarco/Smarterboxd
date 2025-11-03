import SwiftUI

// MARK: - 3. SERVIZIO LOCANDINE
// --- MODIFICATO PESANTEMENTE ---

// Modelli per la PRIMA chiamata (Ricerca)
private struct TMDbResponse: Decodable {
    let results: [TMDbMovie]
}
private struct TMDbMovie: Decodable {
    let id: Int // <-- L'ID di TMDb del film
    let poster_path: String?
}

// Modelli per la SECONDA chiamata (Dettagli + Crediti)
// --- MODIFICATO ---
// Ora può decodificare sia la risposta 'it' che 'en'
private struct TMDbDetailResponse: Decodable {
    let overview: String?
    let credits: TMDbCredits
}
private struct TMDbCredits: Decodable {
    let crew: [TMDbCrewMember]
}
private struct TMDbCrewMember: Decodable {
    let job: String
    let name: String
}

// Struct per contenere tutti i dettagli extra
struct MovieExtraDetails {
    let smallPosterURL: URL?
    let largePosterURL: URL?
    let overview: String?
    let director: String? // Il regista
}

class PosterService {
    // --- 🛑 INSERISCI QUI LA TUA CHIAVE API di TMDb ---
    // (Ottienila gratuitamente da https://www.themoviedb.org/settings/api)
    // ** USA LA "CHIAVE API (v3 auth)" **
    private let tmdbApiKey = "709a0ae9b306cd57cd3c81e90a05fcbc"
    // --- ---------------------------------------- ---
    
    private let imageBaseURL = "https://image.tmdb.org/t/p/w200" // w200 per liste/griglie
    private let largeImageBaseURL = "https://image.tmdb.org/t/p/w500" // w500 per la vista dettaglio
    
    // --- MODIFICATO: Una sola cache per tutti i dettagli
    private var detailsCache: [String: MovieExtraDetails] = [:]
    
    // Singleton: un'unica istanza di questo servizio per tutta l'app
    static let shared = PosterService()
    
    // --- MODIFICATO: Funzione rinominata e potenziata
    // Funzione principale per trovare locandine E trama
    func fetchMovieExtras(title: String, year: String) async -> MovieExtraDetails? {
        // 1. Pulisci l'anno (es. "2023" da "2023")
        let cleanYear = year.components(separatedBy: .decimalDigits.inverted).joined()
        
        // 2. Crea una chiave per la cache
        let cacheKey = "\(title)-\(cleanYear)"
        
        // 3. Controlla la cache
        if let cachedDetails = detailsCache[cacheKey] {
            return cachedDetails
        }
        
        // 4. Prepara la PRIMA richiesta (Ricerca in INGLESE per trovare l'ID)
        guard var searchComponents = URLComponents(string: "https://api.themoviedb.org/3/search/movie") else {
            return nil
        }
        
        // Cerca prima in inglese (en-US) per trovare l'ID e la locandina in modo affidabile
        searchComponents.queryItems = [
            URLQueryItem(name: "api_key", value: tmdbApiKey),
            URLQueryItem(name: "query", value: title), // Il titolo del film
            URLQueryItem(name: "year", value: cleanYear), // L'anno (aiuta a trovare quello giusto)
            URLQueryItem(name: "language", value: "en-US") // Cerca in inglese
        ]
        
        guard let searchURL = searchComponents.url else { return nil }
        
        do {
            // 5. Esegui la PRIMA chiamata (Ricerca)
            let (searchData, _) = try await URLSession.shared.data(from: searchURL)
            let searchResponse = try JSONDecoder().decode(TMDbResponse.self, from: searchData)
            
            // 7. Trova il primo risultato
            guard let firstMovie = searchResponse.results.first else {
                print("Nessun risultato per: \(title)")
                return nil // Non trovato
            }
            
            // Dati dalla prima chiamata
            let tmdbID = firstMovie.id
            let posterPath = firstMovie.poster_path
            
            // Costruisci gli URL delle locandine (questi sono universali)
            let smallURL = posterPath != nil ? URL(string: imageBaseURL + posterPath!) : nil
            let largeURL = posterPath != nil ? URL(string: largeImageBaseURL + posterPath!) : nil
            
            // --- INIZIO SECONDA CHIAMATA (Dettagli in ITALIANO) ---
            
            var italianOverview: String? = nil
            var italianDirector: String? = nil
            
            // 8. Prepara la SECONDA richiesta (Dettagli + Crediti in ITALIANO)
            guard var detailsComponents_it = URLComponents(string: "https://api.themoviedb.org/3/movie/\(tmdbID)") else {
                return nil
            }
            detailsComponents_it.queryItems = [
                URLQueryItem(name: "api_key", value: tmdbApiKey),
                URLQueryItem(name: "language", value: "it-IT"), // Chiedi i dettagli in italiano
                URLQueryItem(name: "append_to_response", value: "credits") // FONDAMENTALE
            ]
            
            guard let detailsURL_it = detailsComponents_it.url else { return nil }
            
            // 9. Esegui la SECONDA chiamata
            let (detailsData_it, _) = try await URLSession.shared.data(from: detailsURL_it)
            if let detailsResponse_it = try? JSONDecoder().decode(TMDbDetailResponse.self, from: detailsData_it) {
                italianOverview = detailsResponse_it.overview
                italianDirector = detailsResponse_it.credits.crew.first(where: { $0.job == "Director" })?.name
            }

            // --- INIZIO TERZA CHIAMATA (Fallback in INGLESE) ---
            
            var englishOverview: String? = nil
            var englishDirector: String? = nil
            
            // 10. Controlla se ci manca qualcosa
            if italianOverview == nil || italianOverview!.isEmpty || italianDirector == nil {
                
                // 11. Prepara la TERZA richiesta (Dettagli + Crediti in INGLESE)
                guard var detailsComponents_en = URLComponents(string: "https://api.themoviedb.org/3/movie/\(tmdbID)") else {
                    return nil
                }
                detailsComponents_en.queryItems = [
                    URLQueryItem(name: "api_key", value: tmdbApiKey),
                    URLQueryItem(name: "language", value: "en-US"), // Chiedi i dettagli in inglese
                    URLQueryItem(name: "append_to_response", value: "credits")
                ]
                
                guard let detailsURL_en = detailsComponents_en.url else { return nil }
                
                // 12. Esegui la TERZA chiamata
                let (detailsData_en, _) = try await URLSession.shared.data(from: detailsURL_en)
                if let detailsResponse_en = try? JSONDecoder().decode(TMDbDetailResponse.self, from: detailsData_en) {
                    englishOverview = detailsResponse_en.overview
                    englishDirector = detailsResponse_en.credits.crew.first(where: { $0.job == "Director" })?.name
                }
            }
            // --- FINE FALLBACK ---

            // 13. Decidi quali dati usare
            // Se la trama italiana è valida, usala. Altrimenti usa quella inglese.
            let finalOverview = (italianOverview != nil && !italianOverview!.isEmpty) ? italianOverview : englishOverview
            
            // Se il regista italiano è valido, usalo. Altrimenti usa quello inglese.
            let finalDirector = (italianDirector != nil) ? italianDirector : englishDirector
            
            // 14. Crea l'oggetto con i dettagli
            let details = MovieExtraDetails(
                smallPosterURL: smallURL,
                largePosterURL: largeURL,
                overview: finalOverview,
                director: finalDirector
            )
            
            // 15. Salva in cache e restituisci
            detailsCache[cacheKey] = details
            return details
            
        } catch {
            print("Errore TMDb per '\(title)': \(error.localizedDescription)")
        }
        
        return nil // Non trovato
    }
}

