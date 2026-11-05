import SwiftUI

struct WatchlistView: View {
    @Environment(WatchlistStore.self) private var store

    enum Layout: String { case grid, list }

    @AppStorage("sortOrder") private var sortOrder: SortOrder = .addedNewest
    @AppStorage("layout") private var layout: Layout = .grid
    @State private var showSettings = false

    private var movies: [Movie] { sortOrder.sorted(store.visibleMovies) }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Group {
                if movies.isEmpty {
                    ContentUnavailableView("Watchlist vuota", systemImage: "film.stack",
                                           description: Text("Hai nascosto tutti i film. Puoi ripristinarli dalle impostazioni."))
                } else if layout == .grid {
                    gridView
                } else {
                    listView
                }
            }
            .navigationTitle("Watchlist")
            .navigationSubtitle(subtitle)
            .movieNavigation()
            .refreshable { await store.refresh() }
            .toolbar { toolbar }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .alert("Sincronizzazione non riuscita", isPresented: Binding(
                get: { store.syncError != nil }, set: { if !$0 { store.syncError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.syncError ?? "")
            }
        }
    }

    private var subtitle: String {
        let count = "\(movies.count) film"
        if store.isSyncing { return "\(count) · Aggiornamento…" }
        return count
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 180), spacing: 14)], spacing: 20) {
                ForEach(movies) { movie in
                    NavigationLink(value: movie) {
                        MovieCardView(movie: movie)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { MovieActions(movie: movie) }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom)
            .animation(.snappy, value: movies)
        }
    }

    private var listView: some View {
        List(movies) { movie in
            NavigationLink(value: movie) {
                MovieRowView(movie: movie)
            }
            .contextMenu { MovieActions(movie: movie) }
            .swipeActions(edge: .trailing) {
                Button("Nascondi", systemImage: "eye.slash", role: .destructive) {
                    withAnimation { store.hide(movie) }
                }
            }
            .swipeActions(edge: .leading) {
                let ranked = store.isRanked(movie)
                Button(ranked ? "Rimuovi" : "Classifica", systemImage: ranked ? "star.slash" : "star.fill") {
                    withAnimation { store.toggleRanked(movie) }
                }
                .tint(.orange)
            }
        }
        .listStyle(.plain)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showSettings = true } label: {
                Image(systemName: "person.crop.circle")
            }
            .accessibilityLabel("Account e impostazioni")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Picker("Ordina", selection: $sortOrder.animation()) {
                    ForEach(SortOrder.allCases) { Text($0.label).tag($0) }
                }
                Section {
                    Picker("Vista", selection: $layout.animation()) {
                        Label("Griglia", systemImage: "square.grid.3x2").tag(Layout.grid)
                        Label("Lista", systemImage: "list.bullet").tag(Layout.list)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
            .accessibilityLabel("Ordina e visualizza")
        }
    }
}
