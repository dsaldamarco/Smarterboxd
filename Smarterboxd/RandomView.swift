import SwiftUI

struct RandomView: View {
    @Environment(WatchlistStore.self) private var store

    /// Da dove pescare: tutta la watchlist o una delle classifiche.
    enum Pool: Hashable {
        case all
        case list(UUID)
    }

    @State private var pool: Pool = .all
    @State private var shuffler = MovieShuffler()

    private var selectedList: RankedList? {
        guard case .list(let id) = pool else { return nil }
        return store.lists.first { $0.id == id }
    }

    private var candidates: [Movie] {
        if let selectedList { return store.movies(in: selectedList) }
        return store.visibleMovies
    }

    var body: some View {
        NavigationStack {
            ShuffleStage(shuffler: shuffler) { placeholder }
                .safeAreaInset(edge: .bottom) { controls }
                .navigationTitle("Random")
                .navigationSubtitle(selectedList.map { Text("From “\($0.title)”") } ?? Text("From your whole watchlist"))
                // Se la lista scelta viene eliminata, torna a tutta la watchlist.
                .onChange(of: store.lists) { if case .list = pool, selectedList == nil { pool = .all } }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Pick from", selection: $pool) {
                                Label("Whole watchlist", systemImage: "film.stack").tag(Pool.all)
                                ForEach(store.lists) { list in
                                    Label(list.title, systemImage: "trophy").tag(Pool.list(list.id))
                                }
                            }
                        } label: {
                            Image(systemName: selectedList == nil ? "film.stack" : "trophy")
                        }
                        .accessibilityLabel("Pick from")
                    }
                }
                .movieNavigation()
        }
    }

    // MARK: - Contenuto

    private var placeholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "dice")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            Text("What should we watch tonight?")
                .font(.title2.weight(.bold))
            Text("Let chance pick from the films in your watchlist, or only from your ranking.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Button { shuffler.shuffle(from: candidates) } label: {
                Label(shuffler.picked == nil ? LocalizedStringKey("Pick a film") : LocalizedStringKey("Pick another"), systemImage: "dice.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(candidates.isEmpty || shuffler.isShuffling)

            if selectedList != nil && candidates.isEmpty {
                Text("This list is empty.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}
