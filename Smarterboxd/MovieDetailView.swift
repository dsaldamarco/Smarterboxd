import SwiftUI

struct MovieDetailView: View {
    @Environment(WatchlistStore.self) private var store
    let movie: Movie

    @State private var details: MovieDetails?
    @State private var isLoaded = false

    private let heroHeight: CGFloat = 340

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                header
                    .padding(.horizontal)
                    .padding(.top, -96)

                VStack(alignment: .leading, spacing: 24) {
                    actions
                    info
                }
                .padding(.horizontal)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = movie.letterboxdURL {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url)
                }
            }
        }
        .task(id: movie.id) {
            details = await TMDbService.shared.details(for: movie)
            withAnimation { isLoaded = true }
        }
    }

    // MARK: - Sezioni

    private var hero: some View {
        Color.clear
            .frame(height: heroHeight)
            .overlay {
                AsyncImage(url: details?.backdropURL ?? details?.posterURL(.large),
                           transaction: Transaction(animation: .easeOut(duration: 0.4))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color(.secondarySystemBackground)
                    }
                }
            }
            .clipped()
            .overlay {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: Color(.systemBackground).opacity(0.7), location: 0.75),
                    .init(color: Color(.systemBackground), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            PosterImage(url: details?.posterURL(.large), title: movie.title, isLoaded: isLoaded, cornerRadius: 12)
                .frame(width: 120)
                .shadow(color: .black.opacity(0.3), radius: 16, y: 8)

            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text([movie.year, details?.formattedRuntime].compactMap { $0?.isEmpty == false ? $0 : nil }
                    .joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let director = details?.director {
                    Text("di **\(director)**")
                        .font(.subheadline)
                }
            }
            .padding(.bottom, 4)
        }
    }

    private var actions: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                let rank = store.rank(of: movie)
                Group {
                    if let rank {
                        Button { toggle() } label: {
                            Label("#\(rank) in classifica", systemImage: "star.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                    } else {
                        Button { toggle() } label: {
                            Label("Aggiungi alla classifica", systemImage: "star")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                .sensoryFeedback(.selection, trigger: rank)

                if let url = movie.letterboxdURL {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right")
                            .accessibilityLabel("Apri su Letterboxd")
                    }
                    .buttonStyle(.glass)
                }
            }
            .font(.body.weight(.semibold))
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private var info: some View {
        if let details {
            if !details.genres.isEmpty || details.rating != nil {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        if let rating = details.rating {
                            Chip(text: rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                        }
                        ForEach(details.genres, id: \.self) { Chip(text: $0) }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }

            if let tagline = details.tagline {
                Text(tagline)
                    .font(.headline)
                    .italic()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Trama").font(.title3.weight(.bold))
                Text(details.overview ?? "Trama non disponibile.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if !isLoaded {
            ProgressView().frame(maxWidth: .infinity)
        } else {
            Text("Dettagli non disponibili.").foregroundStyle(.secondary)
        }

        if let date = movie.formattedDateAdded {
            Label("Aggiunto il \(date)", systemImage: "calendar")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func toggle() {
        withAnimation(.snappy) { store.toggleRanked(movie) }
    }
}

private struct Chip: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).foregroundStyle(.orange) }
            Text(text)
        }
        .font(.footnote.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: .capsule)
    }
}
