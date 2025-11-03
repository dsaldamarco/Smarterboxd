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
    
    // Memoria a lungo termine (salvata su disco)
    @State private var rankedMovieIDs: [String] = []
    
    // --- NOVITÀ ---
    // Un Set per tenere traccia dei film cancellati.
    // Usiamo un Set perché è più veloce per controllare se un ID esiste.
    @State private var deletedMovieIDs: Set<String> = []
    // --- FINE NOVITÀ ---
    
    @State private var currentView: ViewType = .all // Stato del SegmentedControl
    @State private var errorMessage: String? = nil // Eventuale errore
    
    @State private var layoutMode: LayoutType = .list // Stato per Lista/Griglia
    
    // Stato per la vista Random
    @State private var pickedMovie: Movie? = nil
    @State private var isSpinning: Bool = false
    @State private var randomSourceText: String = ""
    
    // Dettagli per il film scelto a caso
    @State private var randomPosterURL: URL? = nil
    @State private var randomOverview: String? = nil
    
    
    // --- PROPRIETÀ CALCOLATA ---
    // Questa è la lista che la UI mostrerà
    var moviesToShow: [Movie] {
        
        // --- MODIFICATO ---
        // 'allMovies' ora contiene solo film validi (non cancellati),
        // quindi non dobbiamo filtrare di nuovo qui.
        
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
                    loadData() // Carica i film E i film cancellati
                    
                    // Carica la classifica salvata
                    self.rankedMovieIDs = loadRankedIDs()
                }
            }
            // Aggiunto .onChange per salvare la classifica
            // ogni volta che 'rankedMovieIDs' cambia
            .onChange(of: rankedMovieIDs) { newIDs in
                saveRankedIDs(newIDs)
            }
            // --- NOVITÀ ---
            // Salva i film cancellati ogni volta che il Set cambia
            .onChange(of: deletedMovieIDs) { newIDs in
                saveDeletedIDs(newIDs)
            }
            // --- FINE NOVITÀ ---
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
            // --- NOVITÀ: Gesto di cancellazione ---
            .onDelete(perform: deleteMovie)
            // --- FINE NOVITÀ ---
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
    
    // --- VISTA RANDOM (MODIFICATA) ---
    private var randomView: some View {
        VStack {
            Spacer()
            
            if isSpinning {
                // --- MODIFICATO ---
                // Sostituito il blocco ProgressView con la nuova SpinnerView
                SpinnerView()
                // --- FINE MODIFICA ---
                
            // --- LAYOUT MODIFICATO DOPO LA SCELTA ---
            } else if let movie = pickedMovie {
                
                VStack(spacing: 15) {
                    Text("Il film scelto \(randomSourceText) è:")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)

                    // 1. Locandina Grande
                    AsyncImage(url: randomPosterURL) { image in
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
                            .overlay(Image(systemName: "film").foregroundColor(.gray.opacity(0.5)))
                    }
                    .frame(maxHeight: 250) // Altezza max per la locandina
                    .padding(.horizontal, 60) // Stringe per farla risaltare
                    
                    // 2. Titolo
                    Text(movie.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // 3. Anno (Quadratino)
                    // Questa view è definita in MovieDetailView.swift
                    InfoBlockView(title: "ANNO", value: movie.year, color: .blue)
                        .padding(.horizontal, 40)
                    
                    // 4. Trama
                    if let overview = randomOverview, !overview.isEmpty {
                        ScrollView(showsIndicators: false) {
                            Text(overview)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxHeight: 100) // Limita l'altezza della trama
                    } else if isSpinning == false {
                        // Mostra un loader solo se NON stiamo girando
                        // (cioè, stiamo caricando i dettagli)
                        ProgressView()
                            .padding()
                    }
                }
                .transition(.opacity)
                .task(id: movie.id) { // <-- .task si ri-esegue quando movie.id cambia
                    await loadRandomMovieDetails(movie: movie)
                }
                
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
    
    // --- MODIFICATO ---
    // Carica i dati dal CSV E filtra quelli cancellati
    func loadData() {
        // 1. Carica gli ID dei film cancellati dal disco
        let loadedDeletedIDsArray = UserDefaults.standard.array(forKey: "deletedMovieIDs") as? [String] ?? []
        let deletedIDsSet = Set(loadedDeletedIDsArray)
        self.deletedMovieIDs = deletedIDsSet
        
        do {
            // 2. Carica TUTTI i film dal CSV
            let allLoadedMovies = try CSVParser.loadMovies(from: "watchlist")
            
            // 3. Filtra i film, tenendo solo quelli NON cancellati
            let validMovies = allLoadedMovies.filter { !deletedIDsSet.contains($0.id) }
            
            // 4. Imposta lo stato dell'app con i soli film validi
            self.allMovies = validMovies
            self.movieLookup = Dictionary(uniqueKeysWithValues: validMovies.map { ($0.id, $0) })
            
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
    
    // --- NOVITÀ: Funzione per cancellare un film ---
    func deleteMovie(at offsets: IndexSet) {
        // 1. Scopri quali film sono stati selezionati
        //    (usa 'moviesToShow' perché è la fonte della lista)
        let moviesToDelete = offsets.map { moviesToShow[$0] }
        
        for movie in moviesToDelete {
            // 2. Aggiungi l'ID ai film cancellati (il .onChange lo salverà)
            deletedMovieIDs.insert(movie.id)
            
            // 3. Rimuovi il film da tutte le liste in memoria
            //    per far aggiornare subito la UI
            allMovies.removeAll { $0.id == movie.id }
            movieLookup.removeValue(forKey: movie.id)
            rankedMovieIDs.removeAll { $0 == movie.id }
        }
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
        // --- MODIFICA ---
        // Resettiamo TUTTO qui, per un'animazione pulita
        await MainActor.run {
            withAnimation(.easeInOut) {
                pickedMovie = nil
                randomPosterURL = nil
                randomOverview = nil
            }
        }
        
        do {
            // Aspetta 1 secondo (1 miliardo di nanosecondi)
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {}
        
        // L'impostazione di pickedMovie qui
        // farà apparire il nuovo blocco in randomView
        if fromRanked {
            if let randomID = rankedMovieIDs.randomElement() {
                self.pickedMovie = movieLookup[randomID]
                self.randomSourceText = "dalla tua classifica"
            }
        } else {
            self.pickedMovie = allMovies.randomElement()
            self.randomSourceText = "dalla tua lista"
        }
        
        isSpinning = false
    }
    
    // --- NOVITÀ ---
    // Carica i dettagli per il film scelto a caso
    func loadRandomMovieDetails(movie: Movie) async {
        // Chiama il service
        let details = await PosterService.shared.fetchMovieExtras(
            title: movie.title,
            year: movie.year
        )
        
        // Aggiorna lo stato sulla Main Thread
        await MainActor.run {
            withAnimation {
                self.randomPosterURL = details?.largePosterURL
                self.randomOverview = details?.overview
            }
        }
    }
    
    // --- FUNZIONI DI SALVATAGGIO (NOVITÀ) ---

    // Salva l'array della classifica su disco
    private func saveRankedIDs(_ ids: [String]) {
        // UserDefaults è il modo più semplice per salvare
        // piccoli dati come un array di stringhe.
        UserDefaults.standard.set(ids, forKey: "rankedMovieIDs")
    }
    
    // Carica l'array della classifica dal disco
    private func loadRankedIDs() -> [String] {
        // Carica i dati salvati, o restituisce un array vuoto
        // se non trova nulla.
        return UserDefaults.standard.array(forKey: "rankedMovieIDs") as? [String] ?? []
    }
    
    // --- NOVITÀ: Funzioni di salvataggio per i film cancellati ---
    
    // Salva il Set di ID cancellati su disco (convertendolo in Array)
    private func saveDeletedIDs(_ ids: Set<String>) {
        let array = Array(ids)
        UserDefaults.standard.set(array, forKey: "deletedMovieIDs")
    }
    
    // (Questa funzione non serve più, loadData se ne occupa)
    // private func loadDeletedIDs() -> Set<String> { ... }
    
}

