import SwiftUI

/// Riga per le viste a lista.
struct MovieRowView: View {
    @Environment(WatchlistStore.self) private var store
    let movie: Movie
    var rank: Int? = nil
    var showsStar = true

    var body: some View {
        MovieDetailsLoader(movie: movie) { details, loaded in
            HStack(spacing: 14) {
                if let rank {
                    Text("\(rank)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(rank <= 3 ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                        .frame(minWidth: 28)
                }

                PosterImage(url: details?.posterURL(), title: "", isLoaded: loaded, cornerRadius: 6)
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(movie.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                    Text(subtitle(details))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if showsStar {
                    let ranked = store.isRanked(movie)
                    Button {
                        withAnimation(.snappy) { store.toggleRanked(movie) }
                    } label: {
                        Image(systemName: ranked ? "star.fill" : "star")
                            .font(.body.weight(.medium))
                            .foregroundStyle(ranked ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 36, height: 36)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: ranked)
                    .accessibilityLabel(ranked ? "Rimuovi dalla classifica" : "Aggiungi alla classifica")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func subtitle(_ details: MovieDetails?) -> String {
        [movie.year, details?.director].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")
    }
}
