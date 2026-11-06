import SwiftUI

/// Carica i dettagli TMDb di un film (dalla cache se disponibili).
struct MovieDetailsLoader<Content: View>: View {
    let movie: Movie
    @ViewBuilder let content: (MovieDetails?, Bool) -> Content

    @State private var details: MovieDetails?
    @State private var isLoaded = false

    var body: some View {
        content(details, isLoaded)
            .task(id: movie.id) {
                details = await TMDbService.shared.details(for: movie)
                isLoaded = true
            }
    }
}

/// Locandina 2:3 con placeholder elegante.
struct PosterImage: View {
    let url: URL?
    let title: String
    var isLoaded = true
    var cornerRadius: CGFloat = 10

    var body: some View {
        Rectangle()
            .fill(.fill.tertiary)
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if isLoaded, url == nil || phase.error != nil {
                        placeholder
                    }
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }
    }

    private var placeholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "film")
                .font(.title3)
            Text(title)
                .font(.caption2.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .foregroundStyle(.secondary)
        .padding(8)
    }
}

struct PosterView: View {
    let movie: Movie
    var size: MovieDetails.ImageSize = .small
    var cornerRadius: CGFloat = 10

    var body: some View {
        MovieDetailsLoader(movie: movie) { details, loaded in
            PosterImage(url: details?.posterURL(size), title: movie.title, isLoaded: loaded, cornerRadius: cornerRadius)
        }
    }
}

/// Badge con il numero in classifica.
struct RankBadge: View {
    let rank: Int

    var body: some View {
        Text(verbatim: "\(rank)")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(.white)
            .frame(minWidth: 24, minHeight: 24)
            .padding(.horizontal, 2)
            .glassEffect(.regular.tint(.orange.opacity(0.8)), in: .capsule)
    }
}

/// Azioni comuni (menu contestuale e swipe).
struct MovieActions: View {
    @Environment(WatchlistStore.self) private var store
    let movie: Movie

    var body: some View {
        // Le classifiche contengono solo film della propria watchlist
        // (in "Insieme" compaiono anche film presenti solo in quella degli amici).
        if store.isInWatchlist(movie) {
            if store.lists.count == 1 {
                let ranked = store.isRanked(movie)
                Button(ranked ? LocalizedStringKey("Remove from ranking") : LocalizedStringKey("Add to ranking"),
                       systemImage: ranked ? "star.slash" : "star") {
                    withAnimation(.snappy) { store.toggleRanked(movie) }
                }
            } else {
                ListMembershipMenu(movie: movie)
            }
        }
        if let url = movie.letterboxdURL {
            Link(destination: url) { Label("Open on Letterboxd", systemImage: "arrow.up.right") }
            ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
        }
        if store.isInWatchlist(movie) {
            Divider()
            Button("Hide", systemImage: "eye.slash", role: .destructive) {
                withAnimation(.snappy) { store.hide(movie) }
            }
        }
    }
}

/// Sottomenu con una spunta per ogni classifica.
struct ListMembershipMenu: View {
    @Environment(WatchlistStore.self) private var store
    let movie: Movie

    var body: some View {
        Menu {
            ForEach(store.lists) { list in
                Toggle(list.title, isOn: Binding(
                    get: { store.list(list.id, contains: movie) },
                    set: { _ in withAnimation(.snappy) { store.toggle(movie, in: list.id) } }
                ))
            }
        } label: {
            Label("Add to list", systemImage: "square.stack")
        }
    }
}
