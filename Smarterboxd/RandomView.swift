import SwiftUI

struct RandomView: View {
    @Environment(WatchlistStore.self) private var store

    enum Pool: String, CaseIterable, Identifiable {
        case all = "Tutta la watchlist"
        case ranked = "Classifica"
        var id: String { rawValue }
    }

    @State private var pool: Pool = .all
    @State private var picked: Movie?
    @State private var shuffleTitle: String?
    @State private var isShuffling = false

    private var candidates: [Movie] { pool == .all ? store.visibleMovies : store.rankedMovies }

    var body: some View {
        NavigationStack {
            ZStack {
                if let picked, !isShuffling {
                    BlurredPosterBackground(movie: picked)
                        .transition(.opacity)
                }

                ScrollView {
                    content
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical)
                }
                .scrollBounceBehavior(.basedOnSize)
                .defaultScrollAnchor(.center)
            }
            .safeAreaInset(edge: .bottom) { controls }
            .navigationTitle("Random")
            .movieNavigation()
            .sensoryFeedback(.selection, trigger: shuffleTitle)
            .sensoryFeedback(.success, trigger: picked)
        }
    }

    // MARK: - Contenuto

    @ViewBuilder
    private var content: some View {
        if isShuffling, let shuffleTitle {
            VStack(spacing: 24) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, value: shuffleTitle)
                Text(shuffleTitle)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .id(shuffleTitle)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .move(edge: .top).combined(with: .opacity)))
            }
            .frame(minHeight: 420)
        } else if let picked {
            PickedMovieView(movie: picked)
                .id(picked.id)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
        } else {
            VStack(spacing: 14) {
                Image(systemName: "dice")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                Text("Cosa guardiamo stasera?")
                    .font(.title2.weight(.bold))
                Text("Lascia scegliere al caso tra i film della tua watchlist o solo tra quelli in classifica.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(minHeight: 420)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Scegli da", selection: $pool) {
                ForEach(Pool.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Button(action: shuffle) {
                Label(picked == nil ? "Scegli un film" : "Scegli un altro", systemImage: "dice.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(candidates.isEmpty || isShuffling)

            if pool == .ranked && candidates.isEmpty {
                Text("La classifica è vuota.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Logica

    private func shuffle() {
        let pool = candidates
        guard !pool.isEmpty, !isShuffling else { return }

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

/// Il film estratto.
private struct PickedMovieView: View {
    let movie: Movie

    var body: some View {
        MovieDetailsLoader(movie: movie) { details, loaded in
            VStack(spacing: 18) {
                NavigationLink(value: movie) {
                    PosterImage(url: details?.posterURL(.large), title: movie.title, isLoaded: loaded, cornerRadius: 16)
                        .frame(maxWidth: 230)
                        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                }
                .buttonStyle(.plain)

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
                        .lineLimit(4)
                }

                NavigationLink(value: movie) {
                    Text("Dettagli")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.glass)
            }
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
