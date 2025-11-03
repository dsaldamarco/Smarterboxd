import Foundation

// MARK: - 3. SERVIZIO LOCANDINE

// Modelli per decodificare la risposta JSON da TMDb
private struct TMDbResponse: Decodable {
    let results: [TMDbMovie]
}
private struct TMDbMovie: Decodable {
    let id: Int? // <-- NOVITÀ: ID del film
    let poster_path: String?
    let overview: String? // la trama
}

// Struct per contenere tutti i dettagli extra
struct MovieExtraDetails {
    let smallPosterURL: URL?
    let largePosterURL: URL?
    let overview: String?
}

class PosterService {
    
    // --- 🛑 ERRORE PRINCIPALE: INSERISCI QUI LA TUA CHIAVE API di TMDb ---
    // (Ottienila gratuitamente da https://www.themoviedb.org/settings/api)
    // ** USA LA "CHIAVE API (v3 auth)" **
    // ** NON usare il "Token di accesso API (v4 auth)" **
    private let tmdbApiKey = "709a0ae9b306cd57cd3c81e90a05fcbc"
    // --- ---------------------------------------- ---
    
    private let imageBaseURL = "https://image.tmdb.org/t/p/w200" // w200 per liste/griglie
    private let largeImageBaseURL = "https://image.tmdb.org/t/p/w500" // w500 per la vista dettaglio
    
    // Una sola cache per tutti i dettagli
    private var detailsCache: [String: MovieExtraDetails] = [:]
    
    // Singleton: un'unica istanza di questo servizio per tutta l'app
    static let shared = PosterService()
    
    // --- NOVITÀ: Funzione helper per prendere la trama in inglese
    private func fetchEnglishOverview(for movieID: Int) async -> String? {
        guard var components = URLComponents(string: "https://api.themoviedb.org/3/movie/\(movieID)") else {
            return nil
        }
        
        // Cerca in 'en-US' (Inglese)
        components.queryItems = [
            URLQueryItem(name: "api_key", value: tmdbApiKey),
            URLQueryItem(name: "language", value: "en-US") // Forza la lingua inglese
        ]
        
        guard let url = components.url else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Per questo usiamo un modello diverso, più semplice
            struct MovieDetailResponse: Decodable {
                let overview: String?
            }
            
            let response = try JSONDecoder().decode(MovieDetailResponse.self, from: data)
            return response.overview
            
        } catch {
            print("Errore nel fetch della trama inglese per ID \(movieID): \(error.localizedDescription)")
            return nil
        }
    }
    
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
        
        // 4. Prepara la richiesta a TMDb
        guard var components = URLComponents(string: "https://api.themoviedb.org/3/search/movie") else {
            return nil
        }
        
        // Aggiungi i parametri all'URL
        components.queryItems = [
            URLQueryItem(name: "api_key", value: tmdbApiKey),
            URLQueryItem(name: "query", value: title), // Il titolo del film
            URLQueryItem(name: "year", value: cleanYear), // L'anno (aiuta a trovare quello giusto)
            URLQueryItem(name: "language", value: "it") // Opzionale: cerca titoli italiani
        ]
        
        guard let url = components.url else { return nil }
        
        // 5. Esegui la chiamata di rete
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // 6. Decodifica la risposta JSON
            let response = try JSONDecoder().decode(TMDbResponse.self, from: data)
            
            // 7. Trova il primo risultato
            if let firstMovie = response.results.first {
                let posterPath = firstMovie.poster_path
                var overview = firstMovie.overview // <-- Reso 'var' (variabile)
                let movieID = firstMovie.id
                
                // --- NOVITÀ: Fallback per la trama in inglese ---
                // Se la trama in italiano è vuota o non c'è,
                // e abbiamo un ID, proviamo a prendere quella inglese.
                if (overview == nil || overview!.isEmpty), let movieID = movieID {
                    print("Trama italiana non trovata per '\(title)', cerco in inglese...")
                    overview = await fetchEnglishOverview(for: movieID)
                }
                // --- FINE NOVITÀ ---
                
                // Costruisci gli URL
                let smallURL = posterPath != nil ? URL(string: imageBaseURL + posterPath!) : nil
                let largeURL = posterPath != nil ? URL(string: largeImageBaseURL + posterPath!) : nil
                
                // Crea l'oggetto con i dettagli
                let details = MovieExtraDetails(
                    smallPosterURL: smallURL,
                    largePosterURL: largeURL,
                    overview: overview
                )
                
                // 8. Salva in cache e restituisci
                detailsCache[cacheKey] = details
                return details
            }
        } catch {
            print("Errore TMDb per '\(title)': \(error.localizedDescription)")
        }
        
        return nil // Non trovato
    }
}

