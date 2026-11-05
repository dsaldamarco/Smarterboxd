import SwiftUI

struct ContentView: View {
    @Environment(WatchlistStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if store.hasWatchlist {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: store.hasWatchlist)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { await store.refreshIfStale() } }
        }
    }
}

struct MainTabView: View {
    @Environment(WatchlistStore.self) private var store

    var body: some View {
        TabView {
            Tab("Watchlist", systemImage: "film.stack") {
                WatchlistView()
            }
            Tab("Classifica", systemImage: "trophy") {
                RankingView()
            }
            Tab("Random", systemImage: "dice") {
                RandomView()
            }
            Tab("Cerca", systemImage: "magnifyingglass", role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

/// Destinazione di navigazione comune.
extension View {
    func movieNavigation() -> some View {
        navigationDestination(for: Movie.self) { MovieDetailView(movie: $0) }
    }
}
