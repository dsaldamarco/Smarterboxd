# Smarterboxd

Un'app iOS per la tua watchlist di [Letterboxd](https://letterboxd.com): scrivi il tuo nome utente e puoi sfogliarla, metterla in ordine, creare la tua classifica dei film da vedere e lasciare al caso la scelta di stasera.

<p align="center">
  <img src="docs/screenshots/onboarding.png" width="200" alt="Schermata iniziale">
  <img src="docs/screenshots/grid.png" width="200" alt="Watchlist a griglia">
  <img src="docs/screenshots/ranking.png" width="200" alt="Classifica">
</p>
<p align="center">
  <img src="docs/screenshots/random.png" width="200" alt="Film scelto a caso">
  <img src="docs/screenshots/detail.png" width="200" alt="Dettaglio film">
  <img src="docs/screenshots/detail-dark.png" width="200" alt="Dettaglio film in modalità scura">
</p>

## Cosa fa

- **Watchlist dal nome utente.** Scrivi il tuo nome utente Letterboxd (oppure `@nome` o il link al profilo) e l'app scarica tutta la watchlist. Si aggiorna da sola quando la riapri, oppure trascinando la lista verso il basso.
- **Griglia o lista**, con cinque ordinamenti: aggiunti di recente o per primi, anno di uscita (dal più recente o dal meno recente), titolo.
- **Classifica personale.** Segna con la stella i film che vuoi vedere prima e riordinali trascinandoli.
- **Random.** Non sai cosa guardare? L'app estrae un film da tutta la watchlist o solo dalla classifica.
- **Dettagli del film**: locandina, immagine di sfondo, regista, durata, generi, voto e trama in italiano (in inglese se manca quella italiana).
- **Ricerca** per titolo o anno.
- **Nascondi** i film che non ti interessano più; puoi ripristinarli dalle impostazioni.
- **Importazione CSV** come alternativa al nome utente.

L'interfaccia è in italiano e segue lo stile nativo di iOS 26, con l'effetto vetro (Liquid Glass) su tab bar, barre e pulsanti, e supporta la modalità scura.

## Come legge la watchlist

Letterboxd ha un'API, ma non è pubblica: l'accesso va richiesto e viene concesso di rado. Smarterboxd legge quindi la pagina pubblica della watchlist (`letterboxd.com/<utente>/watchlist/`), la stessa che vedi dal browser. Ne derivano due limiti:

- **La watchlist deve essere pubblica.**
- **Se Letterboxd cambia la struttura delle sue pagine**, o blocca le richieste, il caricamento dal nome utente può smettere di funzionare finché l'app non viene aggiornata.

In questi casi puoi usare il file CSV: su Letterboxd vai in **Impostazioni › Dati › Esporta i tuoi dati**, estrai lo ZIP e importa `watchlist.csv` dall'app.

Classifica e film nascosti vengono salvati sul telefono e restano anche se passi dal CSV al nome utente o viceversa.

## Requisiti

- Xcode 26 o successivo
- iOS 26 o successivo
- Una chiave API di [TMDb](https://www.themoviedb.org) (gratuita), per locandine e dettagli

## Installazione

1. Clona il repository:
   ```sh
   git clone https://github.com/dsaldamarco/Smarterboxd.git
   cd Smarterboxd
   ```
2. Crea il file con la tua chiave TMDb partendo dall'esempio:
   ```sh
   cp Secrets.example.xcconfig Secrets.xcconfig
   ```
   Apri `Secrets.xcconfig` e incolla la chiave al posto di `INCOLLA_QUI_LA_TUA_CHIAVE`. La trovi su TMDb in **Impostazioni › API**: è la "Chiave API" di 32 caratteri, non il token di accesso. Il file è escluso da git, quindi la chiave non finisce nel repository.
3. Apri `Smarterboxd.xcodeproj` in Xcode e avvia l'app.

Senza chiave l'app funziona lo stesso, ma senza locandine né dettagli dei film.

## Struttura del progetto

| File | Contenuto |
| --- | --- |
| `LetterboxdService.swift` | Scarica e interpreta le pagine della watchlist |
| `CSVParser.swift` | Legge il `watchlist.csv` esportato da Letterboxd |
| `TMDbService.swift` | Locandine e dettagli da TMDb, salvati sul telefono |
| `WatchlistStore.swift` | Stato dell'app: film, classifica, film nascosti, account |
| `*View.swift` | Le schermate in SwiftUI |

## Crediti

Questo prodotto usa l'API di TMDb ma non è approvato né certificato da TMDb.

Smarterboxd è un progetto indipendente e non è affiliato a Letterboxd.

## Licenza

Distribuito con licenza [MIT](LICENSE).
