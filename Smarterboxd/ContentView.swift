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
    
    // Un Set per tenere traccia dei film cancellati.
    // Usiamo un Set perché è più veloce per controllare se un ID esiste.
    @State private var deletedMovieIDs: Set<String> = []
    
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
    
    // --- NOVITÀ: Stato per il regista ---
    @State private var randomDirector: String? = nil
    // --- FINE NOVITÀ ---
    
    @State private var searchText: String = ""
    
    
    // --- PROPRIETÀ CALCOLATA ---
    // Questa è la lista che la UI mostrerà
    var moviesToShow: [Movie] {
        
        // --- MODIFICATO ---
        // 1. Definisci la lista di base (ordinata o classificata)
        let baseList: [Movie]
        
        switch currentView {
        
        case .all:
            // --- VISTA "TUTTI" ---
            switch currentSort {
            case .byDateAdded:
                baseList = allMovies.reversed() // Più recenti aggiunti per primi
            case .byYear:
                baseList = allMovies.sorted { $0.year > $1.year } // Più recenti usciti per primi
            }
            
        case .ranked:
            // --- VISTA "CLASSIFICA" ---
            baseList = rankedMovieIDs.compactMap { id in
                movieLookup[id] // Trova il film corrispondente a ogni ID
            }
            
        case .random:
            baseList = [] // La vista random non usa questa lista
        }
        
        // Se la vista è random, restituisci un array vuoto
        if currentView == .random {
            return []
        }

        // 2. Applica il filtro di ricerca (se presente)
        if searchText.isEmpty {
            return baseList // Nessuna ricerca, restituisci la lista di base
        } else {
            let lowercasedQuery = searchText.lowercased()
            return baseList.filter { movie in
                // Cerca solo nel titolo
                movie.title.lowercased().contains(lowercasedQuery)
            }
        }
        // --- FINE MODIFICA ---
    }
    
    // Colonne per la griglia
    private var gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 150), spacing: 15)
    ]
    
    // --- VISTA ---
    var body: some View {
        NavigationView {
            // --- MODIFICATO: Aggiunto spacing: 0 ---
            VStack(spacing: 0) {
                
                // --- NOVITÀ: Titolo personalizzato ---
                Text("Betterboxd")
                    // Titolo
                
                    .font(.custom("SharpGrotesk-SemiBold20", size: 34))
                    .fontWeight(.bold) // Fallback
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 5) // Spazio prima del contenuto
                
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
                        Text("Filmello").tag(ViewType.ranked)
                        Text("Random").tag(ViewType.random)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // --- VISTA DINAMICA ---
                    if currentView == .all || currentView == .ranked {
                        
                        // --- MODIFICATO ---
                        // Ora la vista lista/griglia è in una
                        // proprietà calcolata separata
                        listAndGridView
                        // --- FINE MODIFICATO ---
                        
                    } else {
                        // --- VISTA RANDOM ---
                        randomView
                    }
                }
            }
            // --- MODIFICATO: Nascondi il titolo di default ---
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // --- FINE MODIFICA ---
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
            // Salva i film cancellati ogni volta che il Set cambia
            .onChange(of: deletedMovieIDs) { newIDs in
                saveDeletedIDs(newIDs)
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
                    
                    // --- MODIFICATO ---
                    // Bottone Edit rimosso (come richiesto)
                    // --- FINE MODIFICA ---
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
    
    // --- NOVITÀ: Proprietà calcolata per la vista Lista/Griglia ---
    // Questo ci permette di applicare .searchable solo a questa vista
    private var listAndGridView: some View {
        VStack {
            // --- LAYOUT DINAMICO (Lista o Griglia) ---
            if layoutMode == .list {
                listView
            } else {
                gridView
            }
        }
        // --- MODIFICATO: La barra di ricerca è applicata QUI ---
        // In questo modo, quando questa vista scompare,
        // scompare anche la barra di ricerca.
        .searchable(text: $searchText, prompt: "Cerca un film...")
        // --- FINE MODIFICA ---
    }
    
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
            // --- MODIFICATO ---
            // Funzione di riordino rimossa perché dipendeva
            // dal pulsante "Modifica"
            // .onMove(perform: movePriority)
            // --- FINE MODIFICA ---
            
            // Gesto di cancellazione (funziona ancora)
            .onDelete(perform: deleteMovie)
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
                            // --- QUESTA È LA CORREZIONE ---
                            // Passiamo il 'rank' (numero) alla MovieCardView
                            rank: (currentView == .ranked) ? (rankedMovieIDs.firstIndex(of: movie.id)) : nil,
                            // --- FINE CORREZIONE ---
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
            // --- MODIFICATO ---
            // Rimosso Spacer() per dare spazio alla ScrollView
            
            if isSpinning {
                Spacer() // Centra lo spinner
                SpinnerView()
                Spacer() // Centra lo spinner
                
            } else if let movie = pickedMovie {
                
                // --- MODIFICA ---
                // L'intero contenuto ora è in una ScrollView
                ScrollView {
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
                        // --- MODIFICA: Altezza ridotta ---
                        .frame(maxHeight: 300) // Era 350
                        .padding(.horizontal, 60)
                        
                        // 2. Titolo
                        Text(movie.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // 3. Info (Anno e Regista)
                        HStack(spacing: 10) {
                            InfoBlockView(title: "ANNO", value: movie.year, color: .blue)
                            
                            // --- NOVITÀ: Blocco Regista ---
                            if let director = randomDirector {
                                InfoBlockView(title: "DIRETTO DA", value: director, color: .green)
                            }
                            // --- FINE NOVITÀ ---
                        }
                        .padding(.horizontal, 40)
                        
                        // 4. Trama
                        if let overview = randomOverview, !overview.isEmpty {
                            // --- MODIFICA: Rimossa la ScrollView interna ---
                            Text(overview)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.top) // Aggiunge spazio
                            // --- MODIFICA: Rimosso .frame(maxHeight: 100)
                            
                        } else if isSpinning == false {
                            ProgressView()
                                .padding()
                        }
                    }
                    .padding(.top) // Spazio in cima alla scroll
                    .padding(.bottom) // Spazio in fondo alla scroll
                    .transition(.opacity)
                    .task(id: movie.id) {
                        await loadRandomMovieDetails(movie: movie)
                    }
                } // --- Fine ScrollView
                
            } else {
                // Messaggio iniziale (centrato con Spacer)
                Spacer()
                Image(systemName: "film.stack")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding()
                Text("Non sai che film guardare?")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Scegli un film a caso da tutta la lista o solo dalla tua classifica.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
            
            // Bottone (visibile solo se non sta girando)
            if !isSpinning {
                // --- MODIFICATO: Stile bottoni ---
                VStack(spacing: 10) { // Spazio ridotto
                    // --- BOTTONE 1: Random da TUTTI ---
                    Button {
                        Task {
                            await runRandomPickerAnimation(fromRanked: false)
                        }
                    } label: {
                        Text(pickedMovie == nil ? "Scegli da Tutta la Lista!" : "Scegli un altro!")
                            .font(.callout) // Testo più piccolo
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(12) // Padding ridotto
                            .background(.thinMaterial) // Effetto trasparente
                            .foregroundColor(.primary) // Colore testo
                            .cornerRadius(10)
                            .overlay( // Bordo opzionale
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    .disabled(allMovies.isEmpty)
                    
                    // --- BOTTONE 2: Random dalla CLASSIFICA ---
                    Button {
                        Task {
                            await runRandomPickerAnimation(fromRanked: true)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "star.fill")
                                .font(.caption) // Icona più piccola
                            Text("Scegli dalla Mia Classifica")
                        }
                        .font(.callout) // Testo più piccolo
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(12) // Padding ridotto
                        .background(rankedMovieIDs.isEmpty ? Color.gray.opacity(0.1) : Color.yellow.opacity(0.15)) // Sfondo trasparente
                        .foregroundColor(rankedMovieIDs.isEmpty ? .secondary : .primary) // Colore testo
                        .cornerRadius(10)
                        .overlay( // Bordo opzionale
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(rankedMovieIDs.isEmpty ? Color.gray : Color.yellow, lineWidth: 1)
                        )
                    }
                    .disabled(rankedMovieIDs.isEmpty)
                    
                }
                .padding(.horizontal)
                .padding(.bottom, 5) // Meno padding in basso
                // --- FINE MODIFICA ---
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
    
    // --- MODIFICATO ---
    // Funzione di riordino rimossa
    /*
    // Chiamata quando l'utente trascina un film nella classifica
    func movePriority(from source: IndexSet, to destination: Int) {
        rankedMovieIDs.move(fromOffsets: source, toOffset: destination)
    }
    */
    // --- FINE MODIFICA ---
    
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
        
        // --- MODIFICATO: CORREZIONE DEL BUG ---
        // La funzione ora costruisce la sua lista sorgente
        // indipendentemente da 'moviesToShow' (che è vuoto in modalità Random)
        
        let sourceList: [Movie]
        let lowercasedQuery = searchText.lowercased()

        if fromRanked {
            // 1. Prendi i film della classifica
            let baseRankedList = rankedMovieIDs.compactMap { movieLookup[$0] }
            
            // 2. Filtra in base alla ricerca (se c'è)
            if searchText.isEmpty {
                sourceList = baseRankedList
            } else {
                sourceList = baseRankedList.filter { $0.title.lowercased().contains(lowercasedQuery) }
            }
            
            // Imposta il testo
            self.randomSourceText = "dalla tua classifica"
            if !searchText.isEmpty {
                self.randomSourceText += " (filtrata)"
            }
            
        } else {
            // 1. Prendi tutti i film
            let baseAllList = allMovies
            
            // 2. Filtra in base alla ricerca (se c'è)
            if searchText.isEmpty {
                sourceList = baseAllList
            } else {
                sourceList = baseAllList.filter { $0.title.lowercased().contains(lowercasedQuery) }
            }
            
            // Imposta il testo
            self.randomSourceText = "dalla tua lista"
            if !searchText.isEmpty {
                self.randomSourceText += " (filtrata)"
            }
        }

        // Controlla se la lista di origine è vuota
        if sourceList.isEmpty {
            return // Non fare nulla
        }
        // --- FINE MODIFICA ---
        
        isSpinning = true
        // --- MODIFKA ---
        // Resettiamo TUTTO qui, per un'animazione pulita
        await MainActor.run {
            withAnimation(.easeInOut) {
                pickedMovie = nil
                randomPosterURL = nil
                randomOverview = nil
                randomDirector = nil // <-- NOVITÀ: Resetta il regista
            }
        }
        
        do {
            // Aspetta 1 secondo (1 miliardo di nanosecondi)
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {}
        
        // Scegli un film dalla lista di origine
        self.pickedMovie = sourceList.randomElement()
        
        isSpinning = false
    }
    
    // --- MODIFICATO ---
    // Carica i dettagli (inclusa la trama e il regista)
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
                self.randomDirector = details?.director // <-- NOVITÀ: Salva il regista
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

