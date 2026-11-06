import SwiftUI

/// Estrazione a sorte con animazione: fa scorrere i titoli e poi rivela il film scelto.
/// Usata da Random e da Insieme.
@Observable
final class MovieShuffler {
    private(set) var picked: Movie?
    private(set) var shuffleTitle: String?
    private(set) var isShuffling = false

    func shuffle(from pool: [Movie]) {
        guard !pool.isEmpty, !isShuffling else { return }

        // Evita di estrarre due volte di fila lo stesso film.
        var choice = pool.randomElement()!
        while pool.count > 1, choice == picked { choice = pool.randomElement()! }
        let finalChoice = choice

        Task {
            // Precarica i dettagli mentre "gira la ruota".
            async let prefetch = TMDbService.shared.details(for: finalChoice)

            withAnimation(.smooth) { isShuffling = true }
            for step in 0..<14 {
                withAnimation(.snappy(duration: 0.18)) { shuffleTitle = pool.randomElement()!.title }
                try? await Task.sleep(for: .milliseconds(45 + step * step))
            }
            _ = await prefetch
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
                picked = finalChoice
                isShuffling = false
                shuffleTitle = nil
            }
        }
    }
}

/// Mostra i titoli che scorrono, il film estratto oppure un segnaposto iniziale.
struct ShuffleStage<Placeholder: View>: View {
    let shuffler: MovieShuffler
    @ViewBuilder var placeholder: Placeholder

    var body: some View {
        ZStack {
            if let picked = shuffler.picked, !shuffler.isShuffling {
                BlurredPosterBackground(movie: picked)
                    .transition(.opacity)
            }

            GeometryReader { proxy in
                ScrollView {
                    content
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical)
                        // Centra il contenuto quando entra nello schermo, altrimenti scorre.
                        .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .tracksTabBarScroll()
            }
        }
        .sensoryFeedback(.selection, trigger: shuffler.shuffleTitle)
        .sensoryFeedback(.success, trigger: shuffler.picked)
    }

    @ViewBuilder
    private var content: some View {
        if shuffler.isShuffling, let title = shuffler.shuffleTitle {
            VStack(spacing: 24) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, value: title)
                Text(title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .id(title)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .move(edge: .top).combined(with: .opacity)))
            }
        } else if let picked = shuffler.picked {
            PickedMovieView(movie: picked)
                .id(picked.id)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
        } else {
            placeholder
        }
    }
}

/// Il film estratto: tutta la scheda apre il dettaglio.
struct PickedMovieView: View {
    let movie: Movie

    var body: some View {
        MovieDetailsLoader(movie: movie) { details, loaded in
            NavigationLink(value: movie) {
                VStack(spacing: 18) {
                    PosterImage(url: details?.posterURL(.large), title: movie.title, isLoaded: loaded, cornerRadius: 16)
                        .frame(maxWidth: 210)
                        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)

                    VStack(spacing: 6) {
                        Text(movie.title)
                            .font(.title.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text([movie.year, details?.director, details?.formattedRuntime]
                            .compactMap { $0?.isEmpty == false ? $0 : nil }
                            .joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let overview = details?.overview {
                        Text(overview)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
                .foregroundStyle(.primary)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Sfondo sfocato ricavato dalla locandina.
struct BlurredPosterBackground: View {
    let movie: Movie

    var body: some View {
        MovieDetailsLoader(movie: movie) { details, _ in
            Color.clear
                .overlay {
                    AsyncImage(url: details?.posterURL()) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { Color.clear }
                }
                .blur(radius: 70)
                .opacity(0.45)
                .clipped()
                .ignoresSafeArea()
        }
    }
}
