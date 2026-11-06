import SwiftUI

struct WatchlistView: View {
    @Environment(WatchlistStore.self) private var store
    @Environment(TabBarScrollState.self) private var tabBar: TabBarScrollState?

    enum Layout: String { case grid, list }

    @AppStorage("sortOrder") private var sortOrder: SortOrder = .addedNewest
    @AppStorage("layout") private var layout: Layout = .grid
    @State private var showSettings = false
    @State private var query = ""
    @State private var isSearching = false

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    /// Watchlist ordinata, filtrata dalla ricerca (per titolo o anno).
    private var movies: [Movie] {
        let all = sortOrder.sorted(store.visibleMovies)
        let q = trimmedQuery
        guard !q.isEmpty else { return all }
        return all.filter { $0.title.localizedStandardContains(q) || $0.year == q }
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Group {
                if movies.isEmpty, !trimmedQuery.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                } else if movies.isEmpty {
                    ContentUnavailableView("Empty watchlist", systemImage: "film.stack",
                                           description: Text("You’ve hidden every film. You can restore them in Settings."))
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
            // La barra di ricerca esiste solo mentre si cerca: aperta dalla lente in alto,
            // sparisce del tutto quando la si chiude.
            .modifier(SearchWhenActive(isActive: isSearching, query: $query, isPresented: $isSearching))
            .onChange(of: isSearching) { _, searching in
                tabBar?.isPaused = searching
                // Chiudendo la ricerca si torna sempre alla watchlist completa.
                if !searching { query = "" }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .alert("Sync failed", isPresented: Binding(
                get: { store.syncError != nil }, set: { if !$0 { store.syncError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.syncError ?? "")
            }
        }
    }

    private var subtitle: Text {
        store.isSyncing ? Text("\(movies.count) films · Updating…") : Text("\(movies.count) films")
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
        .tracksTabBarScroll()
    }

    private var listView: some View {
        List(movies) { movie in
            NavigationLink(value: movie) {
                MovieRowView(movie: movie)
            }
            .contextMenu { MovieActions(movie: movie) }
            .swipeActions(edge: .trailing) {
                Button("Hide", systemImage: "eye.slash", role: .destructive) {
                    withAnimation { store.hide(movie) }
                }
            }
            .swipeActions(edge: .leading) {
                let ranked = store.isRanked(movie)
                Button(ranked ? LocalizedStringKey("Remove") : LocalizedStringKey("Rank"), systemImage: ranked ? "star.slash" : "star.fill") {
                    withAnimation { store.toggleRanked(movie) }
                }
                .tint(.orange)
            }
        }
        .listStyle(.plain)
        .tracksTabBarScroll()
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showSettings = true } label: {
                if let avatarURL = store.avatarURL {
                    ProfileAvatar(name: store.displayName ?? store.username, url: avatarURL, size: 30)
                } else {
                    Image(systemName: "person.crop.circle")
                }
            }
            .accessibilityLabel("Account and settings")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $sortOrder.animation()) {
                    ForEach(SortOrder.allCases) { Text($0.label).tag($0) }
                }
                Section {
                    Picker("View", selection: $layout.animation()) {
                        Label("Grid", systemImage: "square.grid.3x2").tag(Layout.grid)
                        Label("List", systemImage: "list.bullet").tag(Layout.list)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
            .accessibilityLabel("Sort and view")

            Button {
                withAnimation(.smooth) { isSearching = true }
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Search")
        }
    }
}

/// Aggiunge la barra di ricerca solo quando serve.
private struct SearchWhenActive: ViewModifier {
    let isActive: Bool
    @Binding var query: String
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.searchable(text: $query, isPresented: $isPresented,
                               placement: .navigationBarDrawer(displayMode: .always),
                               prompt: Text("Title or year"))
        } else {
            content
        }
    }
}
