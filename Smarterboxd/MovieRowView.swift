import SwiftUI

// MARK: - 5. VISTA RIGA FILM (OTTIMIZZAZIONE)

struct MovieRowView: View {
    let movie: Movie
    let isRanked: Bool
    let rank: Int? // Numero opzionale per la classifica
    let onTogglePriority: () -> Void // Azione per il tap sulla stella
    
    // Stato locale per contenere l'URL della locandina trovato
    @State private var posterURL: URL? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            
            // --- LOCANDINA (NOVITÀ) ---
            AsyncImage(url: posterURL) { image in // Usa lo @State locale
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                // Placeholder grigio
                Rectangle()
                    .foregroundColor(.gray.opacity(0.2))
                    .overlay(Image(systemName: "film"))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .frame(width: 40, height: 60) // Dimensioni standard locandina
            .cornerRadius(4)
            
            // Mostra il numero classifica (es. "1", "2", ...)
            if let rank = rank {
                Text("\(rank + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            
            // Titolo e dettagli
            VStack(alignment: .leading) {
                Text(movie.title)
                    .font(.headline)
                Text("Uscita: \(movie.year) | Aggiunto: \(movie.dateAdded)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer() // Spinge la stella a destra
            
            // --- MODIFICATO ---
            // Sostituito onTapGesture con Button per evitare
            // che il tap si propaghi alla NavigationLink
            Button {
                onTogglePriority() // Esegue l'azione
            } label: {
                Image(systemName: isRanked ? "star.fill" : "star")
                    .foregroundColor(isRanked ? .yellow : .gray)
            }
            .buttonStyle(.plain) // IMPORTANTE: impedisce al bottone di attivare la NavLink
        }
        .padding(.vertical, 4) // Aggiunge un po' di spazio
        .task { // --- NOVITÀ: Caricamento "Lazy" ---
            // Si avvia solo quando la riga appare sullo schermo
            if posterURL == nil { // Carica solo se non l'ha già fatto
                await loadPoster()
            }
        }
    }
    
    // Funzione per chiamare il PosterService
    private func loadPoster() async {
        // --- MODIFICATO: Chiama il nuovo servizio
        let details = await PosterService.shared.fetchMovieExtras(
            title: movie.title,
            year: movie.year
        )
        self.posterURL = details?.smallPosterURL
    }
}
