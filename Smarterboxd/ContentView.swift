import SwiftUI

// MARK: - 4. LA VISTA PRINCIPALE (UI)

struct ContentView: View {
    
    // Enum per definire i tipi di ordinamento
    enum SortType {
        case byDateAdded
        case byYear
    }
    
    // Enum per la vista del Picker
    enum ViewType {
        case all
        case ranked
        case random
    }
    
    // Enum per il layout
    enum LayoutType {
        case list
        case grid
    }
    
    // --- STATO PRINCIPALE ---
    @State private var allMovies: [Movie] = [] // Lista completa dal CSV
    @State private var movieLookup: [String: Movie] = [:] // Per trovare film per ID
    @State private var currentSort: SortType = .byDateAdded // Ordinamento (solo per la vista "Tutti")
    @State private var rankedMovieIDs: [String] = [] // Array ordinato degli ID
    @State private var currentView: ViewType = .all // Stato del SegmentedControl
    @State private var errorMessage: String? = nil // Eventuale errore
    
    @State private var layoutMode: LayoutType = .list // Stato per Lista/Griglia
    
    // Stato per la vista Random
    @State private var pickedMovie: Movie? = nil
    @State private var isSpinning: Bool = false
    @State private var randomSourceText: String = ""
    
    
    // --- PROPRIETÀ CALCOLATA ---
    // Questa è la lista che la UI mostrerà
    var moviesToShow: [Movie] {
        
        switch currentView {
        
        case .all:
            // --- VISTA "TUTTI" ---
            switch currentSort {
            case .byDateAdded:
                return allMovies.reversed() // Più recenti aggiunti per primi
            case .byYear:
                return allMovies.sorted { $0.year > $1.year } // Più recenti usciti per primi
            }
            
        case .ranked:
            // --- VISTA "CLASSIFICA" ---
            return rankedMovieIDs.compactMap { id in
                movieLookup[id] // Trova il film corrispondente a ogni ID
            }
            
        case .random:
            return []
        }
    }
    
    // Colonne per la griglia
    private var gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 150), spacing: 15)
    ]
    
    // --- VISTA ---
    var body: some View {
        NavigationView {
            VStack {
                // Se c'è un errore, mostralo
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                
                // Se la lista è vuota (sta ancora caricando o è vuota)
                } else if allMovies.isEmpty {
                    Text("Caricamento...")
                        .foregroundColor(.secondary)
                
                // Se tutto è a posto, mostra la lista
                } else {
                    
                    // --- SEGMENTED CONTROL ---
                    Picker("Visualizza", selection: $currentView.animation()) {
                        Text("Tutti").tag(ViewType.all)
                        Text("Mia Classifica").tag(ViewType.ranked)
                        Text("Random").tag(ViewType.random)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // --- VISTA DINAMICA ---
                    if currentView == .all || currentView == .ranked {
                        
                        // --- LAYOUT DINAMICO (Lista o Griglia) ---
                        if layoutMode == .list {
                            listView
                        } else {
                            gridView
                        }
                        
                    } else {
                        // --- VISTA RANDOM ---
                        randomView
                    }
                }
            }
            .navigationTitle("Watchlist") // Titolo della barra
            .onAppear {
                // Carica i dati 1 sola volta quando la vista appare
                if allMovies.isEmpty {
                    loadData() // Chiama la funzione locale
                }
            }
            .toolbar {
                // --- GRUPPO 1: Bottoni di Layout e Modifica
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    
                    // Bottone Layout (Lista/Griglia)
                    // Non mostrare in modalità Random
                    if currentView != .random {
                        Button {
                            // Cambia il layout
                            layoutMode = (layoutMode == .list) ? .grid : .list
                        } label: {
                            Image(systemName: layoutMode == .list ? "square.grid.2x2" : "list.bullet")
                        }
                    }
                    
                    // Bottone Edit (solo per Classifica E in modalità Lista)
                    if currentView == .ranked && layoutMode == .list {
                        EditButton() // Abilita il riordino
                    }
                }
                
                // --- GRUPPO 2: Menu Ordinamento
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        // Bottone 1
                        Button("Ordina per Data Aggiunta (Più Recente)") {
                            currentSort = .byDateAdded // Imposta lo @State locale
                        }
                        
                        // Bottone 2
                        Button("Ordina per Anno Uscita (Più Recente)") {
                            currentSort = .byYear // Imposta lo @State locale
                        }
                    } label: {
                        // Etichetta del menu
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                    // Disabilita se non sei in vista "Tutti"
                    .disabled(currentView != .all)
                }
            }
        }
    }
    
    // MARK: - Viste Secondarie (per pulizia)
    
    // La vista per la modalità Lista
    private var listView: some View {
        List {
            ForEach(moviesToShow) { movie in
                NavigationLink(destination: MovieDetailView(movie: movie)) {
                    MovieRowView(
                        movie: movie,
                        isRanked: rankedMovieIDs.contains(movie.id),
                        rank: (currentView == .ranked) ? (rankedMovieIDs.firstIndex(of: movie.id)) : nil,
                        onTogglePriority: {
                            withAnimation {
                                togglePriority(for: movie)
                            }
                        }
                    )
                }
            }
            .onMove(perform: movePriority)
        }
        .listStyle(.plain) // Stile pulito
    }
    
    // La vista per la modalità Griglia
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(moviesToShow) { movie in
                    // La NavigationLink ora avvolge la card
                    NavigationLink(destination: MovieDetailView(movie: movie)) {
                        MovieCardView(
                            movie: movie,
                            isRanked: rankedMovieIDs.contains(movie.id),
                            onTogglePriority: {
                                withAnimation {
                                    togglePriority(for: movie)
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain) // Rende l'intera card cliccabile
                }
            }
            .padding()
        }
    }
    
    // La vista per la modalità Random
    private var randomView: some View {
        VStack {
            Spacer()
            
            if isSpinning {
                // Animazione di caricamento
                ProgressView()
                    .scaleEffect(2) // Più grande
                    .padding()
                Text("Giro la ruota...")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
                
            } else if let movie = pickedMovie {
                // Mostra il film scelto
                Text("Il film scelto \(randomSourceText) è:") // Testo dinamico
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
                
                // Riutilizziamo la MovieRowView
                MovieRowView(
                    movie: movie,
                    isRanked: rankedMovieIDs.contains(movie.id),
                    rank: nil, // Nessun numero qui
                    onTogglePriority: {
                        withAnimation {
                            togglePriority(for: movie)
                        }
                    }
                )
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                
            } else {
                // Messaggio iniziale
                Image(systemName: "film.stack")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding()
                Text("Non sai che film guardare?")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Scegli un film a caso da tutta la lista o solo dalla tua classifica.") // Testo modificato
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Bottone (visibile solo se non sta girando)
            if !isSpinning {
                // --- BOTTONI RANDOM (MODIFICATI) ---
                VStack(spacing: 15) {
                    // --- BOTTONE 1: Random da TUTTI ---
                    Button {
                        // Avvia l'animazione e la scelta
                        Task {
                            await runRandomPickerAnimation(fromRanked: false)
                        }
                    } label: {
                        Text(pickedMovie == nil ? "Scegli da Tutta la Lista!" : "Scegli un altro!")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(allMovies.isEmpty) // Disabilita se la lista è vuota
                    
                    // --- BOTTONE 2: Random dalla CLASSIFICA ---
                    Button {
                        // Avvia l'animazione e la scelta
                        Task {
                            await runRandomPickerAnimation(fromRanked: true)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("Scegli dalla Mia Classifica")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(rankedMovieIDs.isEmpty ? Color.gray : Color.yellow)
                        .foregroundColor(rankedMovieIDs.isEmpty ? .white : .black)
                        .cornerRadius(10)
                    }
                    .disabled(rankedMovieIDs.isEmpty) // Disabilita se la classifica è vuota
                    
                }
                .padding()
            }
        }
        .transition(.opacity) // Transizione per la vista Random
    }
    
    // --- FUNZIONI LOGICHE ---
    
    // Carica i dati dal CSV
    func loadData() {
        do {
            let loadedMovies = try CSVParser.loadMovies(from: "watchlist")
            self.allMovies = loadedMovies
            
            // Crea un "dizionario" per trovare velocemente
            // un film partendo dal suo ID.
            self.movieLookup = Dictionary(uniqueKeysWithValues: loadedMovies.map { ($0.id, $0) })
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // Aggiunge o rimuove un film dalla classifica
    func togglePriority(for movie: Movie) {
        if let index = rankedMovieIDs.firstIndex(of: movie.id) {
            // È già nella classifica, rimuovilo
            rankedMovieIDs.remove(at: index)
        } else {
            // Non è nella classifica, aggiungilo (alla fine)
            rankedMovieIDs.append(movie.id)
        }
    }
    
    // Chiamata quando l'utente trascina un film nella classifica
    func movePriority(from source: IndexSet, to destination: Int) {
        rankedMovieIDs.move(fromOffsets: source, toOffset: destination)
    }
    
    // Gestisce l'animazione e la scelta del film random
    func runRandomPickerAnimation(fromRanked: Bool) async {
        
        // Controlla se la lista appropriata è vuota
        if fromRanked && rankedMovieIDs.isEmpty {
            return // Non fare nulla se si chiede dalla classifica vuota
        }
        if !fromRanked && allMovies.isEmpty {
            return // Non fare nulla se la lista intera è vuota
        }
        
        isSpinning = true
        pickedMovie = nil // Nasconde il film precedente
        
        do {
            // Aspetta 1 secondo (1 miliardo di nanosecondi)
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {}
        
        if fromRanked {
            // --- MODIFICA 1: Scegli dalla CLASSIFICA ---
            if let randomID = rankedMovieIDs.randomElement() {
                self.pickedMovie = movieLookup[randomID]
                self.randomSourceText = "dalla tua classifica"
            }
        } else {
            // --- MODIFICA 2: Scegli da TUTTI ---
            self.pickedMovie = allMovies.randomElement()
            self.randomSourceText = "dalla tua lista"
        }
        
        isSpinning = false
    }
}
