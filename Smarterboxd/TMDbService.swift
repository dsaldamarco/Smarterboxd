import Foundation

/// Dettagli di un film presi da TMDb.
nonisolated struct MovieDetails: Codable, Sendable, Hashable {
    let tmdbID: Int
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let tagline: String?
    let director: String?
    let runtime: Int?
    let genres: [String]
    let rating: Double?

    enum ImageSize: String { case small = "w342", large = "w780", backdrop = "w1280" }

    func posterURL(_ size: ImageSize = .small) -> URL? {
        posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/\(size.rawValue)\($0)") }
    }

    var backdropURL: URL? {
        backdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/\(ImageSize.backdrop.rawValue)\($0)") }
    }

    var formattedRuntime: String? {
        guard let runtime, runtime > 0 else { return nil }
        return runtime >= 60 ? "\(runtime / 60)h \(runtime % 60)m" : "\(runtime)m"
    }
}

/// Cerca locandine, trama e regista su TMDb.
/// Le risposte sono salvate su disco, così ogni film viene scaricato una volta sola.
actor TMDbService {
    static let shared = TMDbService()

    // Chiave v3 di TMDb, letta da Secrets.xcconfig (escluso da git) tramite Info.plist.
    // Ottienila su https://www.themoviedb.org/settings/api
    private let apiKey: String = {
        let key = (Bundle.main.object(forInfoDictionaryKey: "TMDBAPIKey") as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if key.isEmpty || key.hasPrefix("$(") || key == "INCOLLA_QUI_LA_TUA_CHIAVE" {
            print("⚠️ Chiave TMDb mancante: crea Secrets.xcconfig (vedi Secrets.example.xcconfig).")
        }
        return key
    }()

    private var cache: [String: MovieDetails] = [:]
    private var misses: Set<String> = []
    private var inFlight: [String: Task<MovieDetails?, Never>] = [:]
    private var saveTask: Task<Void, Never>?

    private let cacheURL = URL.cachesDirectory.appending(path: "tmdb-cache-v2.json")

    init() {
        if let data = try? Data(contentsOf: cacheURL),
           let saved = try? JSONDecoder().decode([String: MovieDetails].self, from: data) {
            cache = saved
        }
    }

    func cachedDetails(for movie: Movie) -> MovieDetails? { cache[movie.id] }

    func details(for movie: Movie) async -> MovieDetails? {
        if let cached = cache[movie.id] { return cached }
        if misses.contains(movie.id) { return nil }
        if let task = inFlight[movie.id] { return await task.value }

        let task = Task { await fetch(title: movie.title, year: movie.year) }
        inFlight[movie.id] = task
        let result = await task.value
        inFlight[movie.id] = nil

        if let result {
            cache[movie.id] = result
            scheduleSave()
        } else {
            misses.insert(movie.id)
        }
        return result
    }

    // MARK: - Rete

    private nonisolated func fetch(title: String, year: String) async -> MovieDetails? {
        // 1. Ricerca (prima con l'anno, poi senza per i casi limite)
        var hit = await search(title: title, year: year)
        if hit == nil, !year.isEmpty { hit = await search(title: title, year: nil) }
        guard let hit else { return nil }

        // 2. Trama e generi in italiano; crediti in inglese, perché in italiano
        //    TMDb restituisce i nomi nella grafia originale (es. "楊德昌" invece di "Edward Yang").
        async let italianTask = movieDetails(id: hit.id, language: "it-IT", credits: false)
        async let englishTask = movieDetails(id: hit.id, language: "en-US", credits: true)
        let (italian, english) = await (italianTask, englishTask)
        let primary = italian ?? english

        func nonEmpty(_ s: String?) -> String? { (s?.isEmpty ?? true) ? nil : s }

        return MovieDetails(
            tmdbID: hit.id,
            posterPath: hit.poster_path ?? primary?.poster_path,
            backdropPath: primary?.backdrop_path ?? hit.backdrop_path,
            overview: nonEmpty(italian?.overview) ?? nonEmpty(english?.overview),
            tagline: nonEmpty(italian?.tagline) ?? nonEmpty(english?.tagline),
            director: english?.credits?.crew.first { $0.job == "Director" }?.name,
            runtime: primary?.runtime,
            genres: primary?.genres?.map(\.name) ?? [],
            rating: primary?.vote_average.flatMap { $0 > 0 ? $0 : nil }
        )
    }

    private nonisolated func search(title: String, year: String?) async -> SearchResult? {
        var items = [URLQueryItem(name: "query", value: title), URLQueryItem(name: "language", value: "en-US")]
        if let year, !year.isEmpty { items.append(URLQueryItem(name: "year", value: year)) }
        let response: SearchResponse? = await get("search/movie", items)
        return response?.results.first
    }

    private nonisolated func movieDetails(id: Int, language: String, credits: Bool) async -> DetailResponse? {
        var items = [URLQueryItem(name: "language", value: language)]
        if credits { items.append(URLQueryItem(name: "append_to_response", value: "credits")) }
        return await get("movie/\(id)", items)
    }

    private nonisolated func get<T: Decodable>(_ path: String, _ items: [URLQueryItem]) async -> T? {
        var components = URLComponents(string: "https://api.themoviedb.org/3/\(path)")!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)] + items
        guard let url = components.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func scheduleSave() {
        guard saveTask == nil else { return }
        saveTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if let data = try? JSONEncoder().encode(cache) { try? data.write(to: cacheURL, options: .atomic) }
            saveTask = nil
        }
    }
}

// MARK: - Modelli di risposta TMDb

private nonisolated struct SearchResponse: Decodable { let results: [SearchResult] }

private nonisolated struct SearchResult: Decodable {
    let id: Int
    let poster_path: String?
    let backdrop_path: String?
}

private nonisolated struct DetailResponse: Decodable {
    struct Genre: Decodable { let name: String }
    struct Credits: Decodable { let crew: [Crew] }
    struct Crew: Decodable { let job: String; let name: String }

    let overview: String?
    let tagline: String?
    let runtime: Int?
    let vote_average: Double?
    let poster_path: String?
    let backdrop_path: String?
    let genres: [Genre]?
    let credits: Credits?
}
