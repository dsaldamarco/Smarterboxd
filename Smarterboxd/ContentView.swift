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
    @State private var tabBar = TabBarScrollState()

    var body: some View {
        TabView {
            Tab("Watchlist", systemImage: "film.stack") {
                WatchlistView()
            }
            Tab("Ranking", systemImage: "trophy") {
                RankingView()
            }
            Tab("Random", systemImage: "dice") {
                RandomView()
            }
            Tab("Together", systemImage: "popcorn") {
                MovieNightView()
            }
        }
        // Si rimpicciolisce scorrendo in giù e si riapre appena si scorre in su.
        .tabBarMinimizeBehavior(tabBar.isScrollingUp ? .never : .onScrollDown)
        .environment(tabBar)
    }
}

/// Di base iOS riapre la tab bar minimizzata solo quando si torna in cima alla lista.
/// Tenendo traccia della direzione di scorrimento possiamo riaprirla appena si scorre verso l'alto.
@Observable
final class TabBarScrollState {
    var isScrollingUp = false
    /// Durante la ricerca la direzione non va seguita: aprire/chiudere la tastiera sposta la lista
    /// e cambiare la tab bar in quel momento ridisegna la schermata, riaprendo la ricerca.
    var isPaused = false {
        didSet { if isPaused { isScrollingUp = false } }
    }
}

private struct TabBarScrollTracking: ViewModifier {
    @Environment(TabBarScrollState.self) private var state: TabBarScrollState?

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { old, new in
            // Ignora il rimbalzo oltre l'inizio della lista (offset negativo).
            guard let state, !state.isPaused, min(old, new) >= 0 else { return }
            let delta = new - old
            guard abs(delta) > 0.5 else { return }
            let up = delta < 0
            if state.isScrollingUp != up { state.isScrollingUp = up }
        }
    }
}

/// Destinazione di navigazione comune.
extension View {
    func movieNavigation() -> some View {
        navigationDestination(for: Movie.self) { MovieDetailView(movie: $0) }
    }

    /// Da applicare alle liste dentro le tab, perché la tab bar si riapra scorrendo in su.
    func tracksTabBarScroll() -> some View {
        modifier(TabBarScrollTracking())
    }
}
