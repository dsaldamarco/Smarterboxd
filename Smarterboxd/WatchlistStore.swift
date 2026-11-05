import Foundation
import SwiftUI

/// Stato condiviso dell'app: watchlist, classifica, film nascosti e account.
@Observable
final class WatchlistStore {

    enum Source: String { case letterboxd, csv }

    private(set) var movies: [Movie] = []
    private(set) var source: Source?
    private(set) var username: String?
    private(set) var displayName: String?
    private(set) var lastSync: Date?
    private(set) var isSyncing = false
    var syncError: String?

    private(set) var rankedIDs: [String] = [] { didSet { defaults.set(rankedIDs, forKey: Keys.ranked) } }
    private(set) var hiddenIDs: Set<String> = [] { didSet { defaults.set(Array(hiddenIDs), forKey: Keys.hidden) } }

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let moviesURL = URL.applicationSupportDirectory.appending(path: "watchlist.json")

    private enum Keys {
        // Stesse chiavi della versione precedente, così classifica e film cancellati restano.
        static let ranked = "rankedMovieIDs"
        static let hidden = "deletedMovieIDs"
        static let source = "source"
        static let username = "username"
        static let displayName = "displayName"
        static let lastSync = "lastSync"
    }

    init() {
        rankedIDs = defaults.stringArray(forKey: Keys.ranked) ?? []
        hiddenIDs = Set(defaults.stringArray(forKey: Keys.hidden) ?? [])
        source = defaults.string(forKey: Keys.source).flatMap(Source.init)
        username = defaults.string(forKey: Keys.username)
        displayName = defaults.string(forKey: Keys.displayName)
        lastSync = defaults.object(forKey: Keys.lastSync) as? Date
        if let data = try? Data(contentsOf: moviesURL),
           let saved = try? JSONDecoder().decode([Movie].self, from: data) {
            movies = saved
        }
        if movies.isEmpty { source = nil }
        pruneRanking()
    }

    // MARK: - Liste derivate

    var hasWatchlist: Bool { source != nil && !movies.isEmpty }

    var visibleMovies: [Movie] { movies.filter { !hiddenIDs.contains($0.id) } }

    var rankedMovies: [Movie] {
        let lookup = Dictionary(movies.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return rankedIDs.compactMap { lookup[$0] }
    }

    var hiddenCount: Int { movies.count { hiddenIDs.contains($0.id) } }

    func isRanked(_ movie: Movie) -> Bool { rankedIDs.contains(movie.id) }
    func rank(of movie: Movie) -> Int? { rankedIDs.firstIndex(of: movie.id).map { $0 + 1 } }

    // MARK: - Fonti dati

    func connect(username raw: String) async throws {
        isSyncing = true
        defer { isSyncing = false }
        let watchlist = try await LetterboxdService.fetchWatchlist(username: raw)
        apply(movies: watchlist.movies, source: .letterboxd, username: watchlist.username, displayName: watchlist.displayName)
    }

    func importCSV(from url: URL) throws {
        let movies = try CSVParser.loadMovies(from: url)
        apply(movies: movies, source: .csv, username: nil, displayName: nil)
    }

    func refresh() async {
        guard source == .letterboxd, let username, !isSyncing else { return }
        do {
            try await connect(username: username)
            syncError = nil
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            syncError = error.localizedDescription
        }
    }

    /// Aggiorna in automatico se l'ultima sincronizzazione ha più di 30 minuti.
    func refreshIfStale() async {
        guard source == .letterboxd else { return }
        if let lastSync, Date.now.timeIntervalSince(lastSync) < 30 * 60 { return }
        await refresh()
    }

    func signOut() {
        movies = []
        source = nil
        username = nil
        displayName = nil
        lastSync = nil
        try? FileManager.default.removeItem(at: moviesURL)
        for key in [Keys.source, Keys.username, Keys.displayName, Keys.lastSync] { defaults.removeObject(forKey: key) }
    }

    private func apply(movies: [Movie], source: Source, username: String?, displayName: String?) {
        self.movies = movies
        self.source = source
        self.username = username
        self.displayName = displayName
        self.lastSync = .now
        pruneRanking()

        defaults.set(source.rawValue, forKey: Keys.source)
        defaults.set(username, forKey: Keys.username)
        defaults.set(displayName, forKey: Keys.displayName)
        defaults.set(lastSync, forKey: Keys.lastSync)
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(movies) { try? data.write(to: moviesURL, options: .atomic) }
    }

    /// Toglie dalla classifica i film che non sono più in watchlist (es. già visti).
    private func pruneRanking() {
        guard !movies.isEmpty else { return }
        let visible = Set(visibleMovies.map(\.id))
        let pruned = rankedIDs.filter(visible.contains)
        if pruned != rankedIDs { rankedIDs = pruned }
    }

    // MARK: - Classifica

    func toggleRanked(_ movie: Movie) {
        if let index = rankedIDs.firstIndex(of: movie.id) { rankedIDs.remove(at: index) }
        else { rankedIDs.append(movie.id) }
    }

    func moveRanked(from source: IndexSet, to destination: Int) {
        rankedIDs.move(fromOffsets: source, toOffset: destination)
    }

    func removeRanked(at offsets: IndexSet) {
        rankedIDs.remove(atOffsets: offsets)
    }

    func clearRanking() { rankedIDs = [] }

    // MARK: - Film nascosti

    func hide(_ movie: Movie) {
        hiddenIDs.insert(movie.id)
        rankedIDs.removeAll { $0 == movie.id }
    }

    func unhideAll() { hiddenIDs = [] }
}
