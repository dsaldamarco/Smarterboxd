import SwiftUI

/// Confronta la tua watchlist con quella di uno o più amici
/// per trovare i film che potete vedere insieme.
@Observable
final class MovieNightModel {

    nonisolated struct Friend: Codable, Hashable, Identifiable, Sendable {
        var username: String
        var isSelected = true
        var avatarURL: URL?
        var id: String { username }
    }

    struct SharedMovie: Identifiable {
        let movie: Movie
        /// Chi ha il film in watchlist ("Tu", "@marco", ...).
        let owners: [String]
        var id: String { movie.id }
    }

    /// Film presenti in esattamente `count` watchlist.
    struct Overlap: Identifiable {
        let count: Int
        let movies: [SharedMovie]
        var id: Int { count }
    }

    private(set) var friends: [Friend] = [] { didSet { save() } }
    private(set) var overlaps: [Overlap] = []
    private(set) var participantCount = 0
    private(set) var errors: [String: String] = [:]
    private(set) var loadingUsername: String?

    var isLoading: Bool { loadingUsername != nil }
    var hasResults: Bool { participantCount >= 2 }
    var selectedFriends: [Friend] { friends.filter(\.isSelected) }

    /// Film nella watchlist di tutti.
    var commonMovies: [SharedMovie] { overlaps.first { $0.count == participantCount }?.movies ?? [] }

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let friendsKey = "movieNightFriends"
    /// Watchlist degli amici già scaricate (valide 15 minuti), per non riscaricarle a ogni confronto.
    @ObservationIgnored private var cache: [String: (date: Date, movies: [Movie])] = [:]

    init() {
        if let data = defaults.data(forKey: friendsKey),
           let saved = try? JSONDecoder().decode([Friend].self, from: data) {
            friends = saved
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(friends) { defaults.set(data, forKey: friendsKey) }
    }

    // MARK: - Amici

    /// Restituisce un messaggio d'errore se il nome non è valido.
    func addFriend(_ raw: String, ownUsername: String?) -> String? {
        guard let username = LetterboxdService.normalizeUsername(raw) else {
            return String(localized: "Enter a valid username.")
        }
        if username == ownUsername { return String(localized: "That’s you! Add a friend’s username.") }
        if friends.contains(where: { $0.username == username }) { return String(localized: "@\(username) is already in the list.") }
        friends.append(Friend(username: username))
        // Scarica subito la watchlist: serve per la foto profilo e per accorgersi
        // presto di nomi sbagliati o profili privati. Resta in cache per il confronto.
        Task { await preload(username) }
        return nil
    }

    private func preload(_ username: String) async {
        do {
            _ = try await watchlist(of: username)
            errors[username] = nil
        } catch {
            errors[username] = error.localizedDescription
        }
    }

    /// Scarica la foto profilo degli amici aggiunti prima che l'app la salvasse.
    func loadMissingAvatars() async {
        for friend in friends where friend.avatarURL == nil && errors[friend.username] == nil {
            await preload(friend.username)
        }
    }

    func toggle(_ friend: Friend) {
        guard let index = friends.firstIndex(where: { $0.id == friend.id }) else { return }
        friends[index].isSelected.toggle()
    }

    func removeFriends(at offsets: IndexSet) {
        friends.remove(atOffsets: offsets)
    }

    // MARK: - Confronto

    func compare(with store: WatchlistStore) async {
        let selected = selectedFriends
        guard !selected.isEmpty, !isLoading else { return }
        errors = [:]

        let mine = store.visibleMovies
        var participants: [(name: String, ids: Set<String>)] = [(String(localized: "You"), Set(mine.map(\.id)))]
        var catalog = Dictionary(mine.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        // Una persona alla volta, per non sovraccaricare Letterboxd.
        for friend in selected {
            loadingUsername = friend.username
            do {
                let movies = try await watchlist(of: friend.username)
                participants.append(("@\(friend.username)", Set(movies.map(\.id))))
                for movie in movies where catalog[movie.id] == nil { catalog[movie.id] = movie }
            } catch {
                errors[friend.username] = error.localizedDescription
            }
        }
        loadingUsername = nil

        var owners: [String: [String]] = [:]
        for participant in participants {
            for id in participant.ids { owners[id, default: []].append(participant.name) }
        }

        let total = participants.count
        // In due: solo i film in comune. In tre o più: anche quelli che ha "quasi" tutto il gruppo.
        overlaps = total < 2 ? [] : stride(from: total, through: 2, by: -1).compactMap { count in
            let movies = owners
                .filter { $0.value.count == count }
                .compactMap { id, names in catalog[id].map { SharedMovie(movie: $0, owners: names) } }
                .sorted { $0.movie.title.localizedStandardCompare($1.movie.title) == .orderedAscending }
            // La sezione "tutti" resta anche se vuota, per dirlo esplicitamente.
            return movies.isEmpty && count != total ? nil : Overlap(count: count, movies: movies)
        }
        participantCount = total
    }

    private func watchlist(of username: String) async throws -> [Movie] {
        if let cached = cache[username], Date.now.timeIntervalSince(cached.date) < 15 * 60 { return cached.movies }
        let watchlist = try await LetterboxdService.fetchWatchlist(username: username)
        cache[username] = (.now, watchlist.movies)
        if let index = friends.firstIndex(where: { $0.username == username }),
           friends[index].avatarURL != watchlist.avatarURL {
            friends[index].avatarURL = watchlist.avatarURL
        }
        return watchlist.movies
    }
}

struct MovieNightView: View {
    @Environment(WatchlistStore.self) private var store

    @State private var model = MovieNightModel()
    @State private var newFriend = ""
    @State private var addError: String?
    @State private var showPicker = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                peopleSection
                compareSection
                if model.hasResults { results }
            }
            .tracksTabBarScroll()
            .task {
                // Account collegato prima che l'app salvasse la foto profilo: basta una sincronizzazione.
                if store.avatarURL == nil, store.username != nil { await store.refresh() }
                await model.loadMissingAvatars()
            }
            .navigationTitle("Movie night")
            .movieNavigation()
            .toolbar {
                if !model.commonMovies.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showPicker = true } label: {
                            Image(systemName: "dice")
                        }
                        .accessibilityLabel("Pick a film in common at random")
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                MovieNightPickSheet(candidates: model.commonMovies.map(\.movie),
                                    peopleCount: model.participantCount)
            }
            .sensoryFeedback(.success, trigger: model.participantCount)
            .animation(.smooth, value: model.hasResults)
        }
    }

    // MARK: - Sezioni

    private var peopleSection: some View {
        Section {
            HStack(spacing: 12) {
                ProfileAvatar(name: store.displayName ?? store.username, url: store.avatarURL)
                Text(store.username.map { "@\($0)" } ?? String(localized: "Your watchlist"))
                Spacer()
                Text("You").foregroundStyle(.secondary)
            }

            ForEach(model.friends) { friend in
                Button { withAnimation(.snappy) { model.toggle(friend) } } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            ProfileAvatar(name: friend.username, url: friend.avatarURL, isDimmed: !friend.isSelected)
                            Text(verbatim: "@\(friend.username)")
                                .foregroundStyle(friend.isSelected ? .primary : .secondary)
                            Spacer()
                            Image(systemName: friend.isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(friend.isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        if let error = model.errors[friend.username] {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(friend.isSelected ? .isSelected : [])
            }
            .onDelete { model.removeFriends(at: $0) }

            HStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                TextField("Friend’s Letterboxd username", text: $newFriend)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($fieldFocused)
                    .onSubmit(addFriend)
                if !newFriend.isEmpty {
                    Button("Add", action: addFriend)
                        .buttonStyle(.glass)
                }
            }
        } header: {
            Text("Who’s watching")
        } footer: {
            if let addError {
                Text(addError).foregroundStyle(.red)
            } else {
                Text("Tap a friend to include or exclude them tonight. Their watchlists must be public.")
            }
        }
    }

    private var compareSection: some View {
        Section {
            Button {
                fieldFocused = false
                Task { await model.compare(with: store) }
            } label: {
                Group {
                    if let username = model.loadingUsername {
                        HStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text("Loading @\(username)…")
                        }
                    } else {
                        Label("Find films in common", systemImage: "popcorn")
                    }
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(model.selectedFriends.isEmpty || model.isLoading)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    @ViewBuilder
    private var results: some View {
        ForEach(model.overlaps) { overlap in
            let everyone = overlap.count == model.participantCount
            Section {
                if overlap.movies.isEmpty {
                    Text("No film is in everyone’s watchlist. Try with fewer people.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(overlap.movies) { shared in
                        NavigationLink(value: shared.movie) {
                            MovieRowView(movie: shared.movie,
                                         footnote: everyone ? nil : shared.owners.formatted(.list(type: .and)))
                        }
                        .contextMenu { MovieActions(movie: shared.movie) }
                    }
                }
            } header: {
                HStack {
                    if everyone {
                        Text(model.participantCount == 2 ? "In both watchlists" : "In everyone’s watchlist")
                    } else {
                        Text("In \(overlap.count) of \(model.participantCount) watchlists")
                    }
                    Spacer()
                    Text(overlap.movies.count.formatted())
                }
            }
        }
    }

    private func addFriend() {
        let name = newFriend.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        withAnimation(.snappy) {
            addError = model.addFriend(name, ownUsername: store.username)
            if addError == nil { newFriend = "" }
        }
    }
}

/// Estrazione animata tra i film in comune, aperta dal dado in alto.
private struct MovieNightPickSheet: View {
    let candidates: [Movie]
    let peopleCount: Int

    @Environment(\.dismiss) private var dismiss
    @State private var shuffler = MovieShuffler()

    var body: some View {
        NavigationStack {
            ShuffleStage(shuffler: shuffler) { EmptyView() }
                .safeAreaInset(edge: .bottom) {
                    Button { shuffler.shuffle(from: candidates) } label: {
                        Label("Pick another", systemImage: "dice.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(shuffler.isShuffling || candidates.count < 2)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }
                .navigationTitle("Movie night")
                .navigationSubtitle(Text("From \(candidates.count) films in common"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
                    }
                }
                .movieNavigation()
        }
        // L'estrazione parte appena si apre il foglio.
        .task { shuffler.shuffle(from: candidates) }
    }
}
