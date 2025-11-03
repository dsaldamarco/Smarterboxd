import SwiftUI

// MARK: - 7. VISTA DETTAGLIO FILM

struct MovieDetailView: View {
    let movie: Movie
    
    @State private var posterURL: URL? = nil
    @State private var overview: String? = nil
    @State private var isLoading: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // --- LOCANDINA GRANDE ---
                AsyncImage(url: posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                } placeholder: {
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.2))
                        .aspectRatio(CGSize(width: 2, height: 3), contentMode: .fit)
                        .cornerRadius(12)
                        .overlay(Image(systemName: "film"))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.horizontal)
                
                // --- DETTAGLI ---
                VStack(alignment: .leading, spacing: 15) {
                    Text(movie.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // --- BLOCCHI INFO (NOVITÀ) ---
                    HStack(spacing: 10) {
                        // Blocco Anno
                        InfoBlockView(title: "ANNO", value: movie.year, color: .blue)
                        
                        // Blocco Aggiunto
                        InfoBlockView(title: "AGGIUNTO IL", value: movie.dateAdded, color: .green)
                    }
                    
                    // --- TRAMA (NOVITÀ) ---
                    Text("Trama")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    if isLoading {
                        ProgressView() // Mostra un loader mentre carica la trama
                    } else if let overview = overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Trama non disponibile.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding(.horizontal)
                
                Spacer() // Spinge tutto in alto
            }
            .padding(.top)
        }
        .navigationTitle(movie.title) // Mostra il titolo nella barra (ma piccolo)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Carica i dettagli (locandina GRANDE e trama)
            if posterURL == nil {
                await loadDetails()
            }
        }
    }
    
    // Funzione per chiamare il PosterService
    private func loadDetails() async {
        let details = await PosterService.shared.fetchMovieExtras(
            title: movie.title,
            year: movie.year
        )
        
        // Aggiorna lo stato sulla Main Thread
        await MainActor.run {
            self.posterURL = details?.largePosterURL
            self.overview = details?.overview
            self.isLoading = false // Finito di caricare
        }
    }
}

// MARK: - Vista Helper per i blocchi info
struct InfoBlockView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
