import SwiftUI

// MARK: - 1. IL MODELLO

struct Movie: Identifiable, Hashable { // Aggiunto Hashable per NavigationLink
    let id: String // L'URL di Letterboxd
    let title: String
    let year: String
    let dateAdded: String
    
    // Questa variabile conterrà l'URL della locandina
    // che troveremo tramite l'API di TMDb
    var posterURL: URL?
}
