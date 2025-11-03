import SwiftUI

// MARK: - 6. VISTA CARD FILM
// --- MODIFICATO ---
// Aggiunto il parametro 'rank' e l'overlay per il numero

struct MovieCardView: View {
    let movie: Movie
    let isRanked: Bool
    let rank: Int? // <-- NOVITÀ: Numero opzionale per la classifica
    let onTogglePriority: () -> Void // Azione per il tap sulla stella
    
    @State private var posterURL: URL? = nil
    
    var body: some View {
        VStack(alignment: .leading) {
            // --- LOCANDINA ---
            AsyncImage(url: posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(CGSize(width: 2, height: 3), contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.2))
                    .aspectRatio(CGSize(width: 2, height: 3), contentMode: .fit) // Mantiene la forma
                    .overlay(Image(systemName: "film"))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .cornerRadius(8)
            .overlay(
                // --- Bottone Stella (in overlay, top-right) ---
                Button {
                    onTogglePriority()
                } label: {
                    Image(systemName: isRanked ? "star.fill" : "star")
                        .foregroundColor(isRanked ? .yellow : .gray)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(5),
                alignment: .topTrailing // Posiziona in alto a destra
            )
            // --- CORREZIONE: Sintassi overlay e allineamento ---
            .overlay(alignment: .topLeading) { // <-- 1. Usa .topLeading e la sintassi con chiusura
                // Mostra il numero solo se 'rank' esiste (cioè, in vista Classifica)
                if let rank = rank { // <-- 2. Ora questo 'if' è valido
                    Text("\(rank + 1)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(6)
                        .padding(5)
                }
                // (Non serve un 'else' in questa sintassi)
            }
            // --- FINE CORREZIONE ---
            
            // --- DETTAGLI TESTUALI ---
            Text(movie.title)
                .font(.headline)
                .lineLimit(1) // Massimo 1 riga
            
            Text(movie.year)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .task {
            // Carica la locandina quando la card appare
            if posterURL == nil {
                await loadPoster()
            }
        }
    }
    
    // Funzione per chiamare il PosterService
    private func loadPoster() async {
        // Chiama il nuovo servizio
        let details = await PosterService.shared.fetchMovieExtras(
            title: movie.title,
            year: movie.year
        )
        self.posterURL = details?.smallPosterURL
    }
}

