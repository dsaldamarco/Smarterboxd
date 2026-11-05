import SwiftUI

struct SearchView: View {
    @Environment(WatchlistStore.self) private var store
    @State private var query = ""

    private var results: [Movie] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return SortOrder.title.sorted(store.visibleMovies.filter {
            $0.title.localizedStandardContains(q) || $0.year == q
        })
    }

    var body: some View {
        NavigationStack {
            List(results) { movie in
                NavigationLink(value: movie) {
                    MovieRowView(movie: movie)
                }
                .contextMenu { MovieActions(movie: movie) }
            }
            .listStyle(.plain)
            .overlay {
                if query.isEmpty {
                    ContentUnavailableView("Cerca nella watchlist", systemImage: "magnifyingglass",
                                           description: Text("Per titolo o anno di uscita."))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Cerca")
            .movieNavigation()
        }
        .searchable(text: $query, prompt: "Titolo o anno")
    }
}
