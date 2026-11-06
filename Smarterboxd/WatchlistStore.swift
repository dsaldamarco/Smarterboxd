import Foundation
import SwiftUI

/// Una classifica personale (es. "Da vedere con gli amici").
nonisolated struct RankedList: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    /// Vuoto per la classifica predefinita, finché non viene rinominata.
    var name: String
    var movieIDs: [String] = []

    /// Nome da mostrare: quello della classifica predefinita segue la lingua dell'app.
    var title: String { name.isEmpty ? String(localized: "My ranking") : name }
}

/// Stato condiviso dell'app: watchlist, classifiche, film nascosti e account.
@Observable
final class WatchlistStore {

    enum Source: String { case letterboxd, csv }

    private(set) var movies: [Movie] = [] { didSet { movieIDs = Set(movies.map(\.id)) } }
    @ObservationIgnored private var movieIDs: Set<String> = []
    private(set) var source: Source?
    private(set) var username: String?
    private(set) var displayName: String?
    private(set) var avatarURL: URL?
    private(set) var lastSync: Date?
    private(set) var isSyncing = false
    var syncError: String?

    /// Tutte le classifiche; ce n'è sempre almeno una.
    private(set) var lists: [RankedList] = [] { didSet { saveLists() } }
    /// La classifica aperta: la stella e i badge si riferiscono a questa.
    var activeListID = UUID() { didSet { defaults.set(activeListID.uuidString, forKey: Keys.activeList) } }
    private(set) var hiddenIDs: Set<String> = [] { didSet { defaults.set(Array(hiddenIDs), forKey: Keys.hidden) } }

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let moviesURL = URL.applicationSupportDirectory.appending(path: "watchlist.json")

    private enum Keys {
        // Stesse chiavi della versione precedente, così classifica e film cancellati restano.
        static let ranked = "rankedMovieIDs"   // vecchia classifica unica, migrata in `lists`
        static let lists = "rankedLists"
        static let activeList = "activeListID"
        static let hidden = "deletedMovieIDs"
        static let source = "source"
        static let username = "username"
        static let displayName = "displayName"
        static let avatarURL = "avatarURL"
        static let lastSync = "lastSync"
    }

    init() {
        if let data = defaults.data(forKey: Keys.lists),
           let saved = try? JSONDecoder().decode([RankedList].self, from: data), !saved.isEmpty {
            lists = saved
        } else {
            // Prima apertura, o aggiornamento dalla versione con una sola classifica.
            lists = [RankedList(name: "",
                                movieIDs: defaults.stringArray(forKey: Keys.ranked) ?? [])]
        }
        let savedActive = defaults.string(forKey: Keys.activeList).flatMap(UUID.init)
        activeListID = lists.contains { $0.id == savedActive } ? savedActive! : lists[0].id
        hiddenIDs = Set(defaults.stringArray(forKey: Keys.hidden) ?? [])
        source = defaults.string(forKey: Keys.source).flatMap(Source.init)
        username = defaults.string(forKey: Keys.username)
        displayName = defaults.string(forKey: Keys.displayName)
        avatarURL = defaults.url(forKey: Keys.avatarURL)
        lastSync = defaults.object(forKey: Keys.lastSync) as? Date
        if let data = try? Data(contentsOf: moviesURL),
           let saved = try? JSONDecoder().decode([Movie].self, from: data) {
            movies = saved
        }
        if movies.isEmpty { source = nil }
        movieIDs = Set(movies.map(\.id))
        pruneRanking()
    }

    // MARK: - Liste derivate

    var hasWatchlist: Bool { source != nil && !movies.isEmpty }

    var visibleMovies: [Movie] { movies.filter { !hiddenIDs.contains($0.id) } }

    var hiddenCount: Int { movies.count { hiddenIDs.contains($0.id) } }

    func isInWatchlist(_ movie: Movie) -> Bool { movieIDs.contains(movie.id) }

    // MARK: - Classifiche (lettura)

    var activeList: RankedList { lists.first { $0.id == activeListID } ?? lists[0] }

    /// Film della classifica aperta, nell'ordine scelto.
    var rankedMovies: [Movie] { movies(in: activeList) }

    func movies(in list: RankedList) -> [Movie] {
        let lookup = Dictionary(movies.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return list.movieIDs.compactMap { lookup[$0] }
    }

    func isRanked(_ movie: Movie) -> Bool { activeList.movieIDs.contains(movie.id) }
    func rank(of movie: Movie) -> Int? { activeList.movieIDs.firstIndex(of: movie.id).map { $0 + 1 } }
    func list(_ id: UUID, contains movie: Movie) -> Bool {
        lists.first { $0.id == id }?.movieIDs.contains(movie.id) ?? false
    }

    // MARK: - Fonti dati

    func connect(username raw: String) async throws {
        isSyncing = true
        defer { isSyncing = false }
        let watchlist = try await LetterboxdService.fetchWatchlist(username: raw)
        apply(movies: watchlist.movies, source: .letterboxd, username: watchlist.username, displayName: watchlist.displayName,
              avatarURL: watchlist.avatarURL)
    }

    func importCSV(from url: URL) throws {
        let movies = try CSVParser.loadMovies(from: url)
        apply(movies: movies, source: .csv, username: nil, displayName: nil, avatarURL: nil)
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
        avatarURL = nil
        lastSync = nil
        try? FileManager.default.removeItem(at: moviesURL)
        for key in [Keys.source, Keys.username, Keys.displayName, Keys.avatarURL, Keys.lastSync] { defaults.removeObject(forKey: key) }
    }

    private func apply(movies: [Movie], source: Source, username: String?, displayName: String?, avatarURL: URL?) {
        self.movies = movies
        self.source = source
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.lastSync = .now
        pruneRanking()

        defaults.set(source.rawValue, forKey: Keys.source)
        defaults.set(username, forKey: Keys.username)
        defaults.set(displayName, forKey: Keys.displayName)
        defaults.set(avatarURL, forKey: Keys.avatarURL)
        defaults.set(lastSync, forKey: Keys.lastSync)
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(movies) { try? data.write(to: moviesURL, options: .atomic) }
    }

    /// Toglie dalle classifiche i film che non sono più in watchlist (es. già visti).
    private func pruneRanking() {
        guard !movies.isEmpty else { return }
        let visible = Set(visibleMovies.map(\.id))
        let pruned = lists.map { list in
            var list = list
            list.movieIDs = list.movieIDs.filter(visible.contains)
            return list
        }
        if pruned != lists { lists = pruned }
    }

    private func saveLists() {
        if let data = try? JSONEncoder().encode(lists) { defaults.set(data, forKey: Keys.lists) }
    }

    private func updateList(_ id: UUID, _ change: (inout RankedList) -> Void) {
        guard let index = lists.firstIndex(where: { $0.id == id }) else { return }
        change(&lists[index])
    }

    // MARK: - Classifiche (modifica)

    /// Aggiunge o toglie il film dalla classifica aperta.
    func toggleRanked(_ movie: Movie) { toggle(movie, in: activeListID) }

    func toggle(_ movie: Movie, in listID: UUID) {
        updateList(listID) { list in
            if let index = list.movieIDs.firstIndex(of: movie.id) { list.movieIDs.remove(at: index) }
            else { list.movieIDs.append(movie.id) }
        }
    }

    func moveRanked(from source: IndexSet, to destination: Int) {
        updateList(activeListID) { $0.movieIDs.move(fromOffsets: source, toOffset: destination) }
    }

    func removeRanked(at offsets: IndexSet) {
        updateList(activeListID) { $0.movieIDs.remove(atOffsets: offsets) }
    }

    func clearRanking() { updateList(activeListID) { $0.movieIDs = [] } }

    /// Crea una classifica nuova e la apre.
    func createList(named name: String) {
        let list = RankedList(name: name)
        lists.append(list)
        activeListID = list.id
    }

    func renameList(_ id: UUID, to name: String) { updateList(id) { $0.name = name } }

    func deleteList(_ id: UUID) {
        guard lists.count > 1 else { return }
        lists.removeAll { $0.id == id }
        if activeListID == id { activeListID = lists[0].id }
    }

    // MARK: - Film nascosti

    func hide(_ movie: Movie) {
        hiddenIDs.insert(movie.id)
        lists = lists.map { list in
            var list = list
            list.movieIDs.removeAll { $0 == movie.id }
            return list
        }
    }

    func unhideAll() { hiddenIDs = [] }
}
