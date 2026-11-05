import SwiftUI

struct RankingView: View {
    @Environment(WatchlistStore.self) private var store

    var body: some View {
        let ranked = store.rankedMovies
        NavigationStack {
            Group {
                if ranked.isEmpty {
                    ContentUnavailableView {
                        Label("Nessun film in classifica", systemImage: "trophy")
                    } description: {
                        Text("Tocca la stella accanto a un film, oppure tieni premuto su una locandina e scegli «Aggiungi alla classifica».")
                    }
                } else {
                    List {
                        ForEach(Array(ranked.enumerated()), id: \.element.id) { index, movie in
                            NavigationLink(value: movie) {
                                MovieRowView(movie: movie, rank: index + 1, showsStar: false)
                            }
                            .contextMenu { MovieActions(movie: movie) }
                        }
                        .onMove { store.moveRanked(from: $0, to: $1) }
                        .onDelete { store.removeRanked(at: $0) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Classifica")
            .navigationSubtitle(ranked.isEmpty ? "" : "Trascina per riordinare")
            .movieNavigation()
            .toolbar {
                if !ranked.isEmpty { EditButton() }
            }
        }
    }
}
