import SwiftUI

/// Card per la vista a griglia.
struct MovieCardView: View {
    @Environment(WatchlistStore.self) private var store
    let movie: Movie

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterView(movie: movie)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                .overlay(alignment: .topTrailing) {
                    if let rank = store.rank(of: movie) {
                        RankBadge(rank: rank)
                            .padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(movie.title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Text(movie.year)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(.rect)
    }
}
