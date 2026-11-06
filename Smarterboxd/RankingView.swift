import SwiftUI

struct RankingView: View {
    @Environment(WatchlistStore.self) private var store

    /// Quale finestra di inserimento nome è aperta.
    private enum NameEditor: Identifiable {
        case create, rename
        var id: Self { self }
    }

    @State private var nameEditor: NameEditor?
    @State private var draftName = ""
    @State private var confirmDelete = false
    @State private var confirmClear = false

    var body: some View {
        let list = store.activeList
        let ranked = store.rankedMovies

        NavigationStack {
            Group {
                if ranked.isEmpty {
                    ContentUnavailableView {
                        Label("This list is empty", systemImage: "trophy")
                    } description: {
                        Text("Tap the star next to a film to add it here, or press and hold a poster to choose a list.")
                    } actions: {
                        if store.lists.count == 1 {
                            Button("New list", systemImage: "plus") { openEditor(.create) }
                                .buttonStyle(.glass)
                        }
                    }
                } else {
                    List {
                        ForEach(Array(ranked.enumerated()), id: \.element.id) { index, movie in
                            NavigationLink(value: movie) {
                                MovieRowView(movie: movie, rank: index + 1, showsStar: false)
                            }
                            .contextMenu { MovieActions(movie: movie) }
                        }
                        .onMove { store.moveRanked(from: $0, to: $1) }
                        .onDelete { store.removeRanked(at: $0) }
                    }
                    .listStyle(.plain)
                    .tracksTabBarScroll()
                }
            }
            .navigationTitle(list.title)
            .navigationSubtitle(ranked.isEmpty ? Text(verbatim: "") : Text("\(ranked.count) films · Drag to reorder"))
            .toolbarTitleMenu { listMenu }
            .movieNavigation()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu { listMenu } label: {
                        Image(systemName: "square.stack")
                    }
                    .accessibilityLabel("Lists")
                }
                if !ranked.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { EditButton() }
                }
            }
            .alert(nameEditor == .rename ? Text("Rename list") : Text("New list"), isPresented: Binding(
                get: { nameEditor != nil }, set: { if !$0 { nameEditor = nil } }
            )) {
                TextField("Name", text: $draftName)
                Button("Cancel", role: .cancel) {}
                Button(nameEditor == .rename ? LocalizedStringKey("Rename") : LocalizedStringKey("Create")) { saveName() }
                    .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                if nameEditor == .create {
                    Text("For example “With friends” or “Date night”.")
                }
            }
            .confirmationDialog("Delete “\(list.title)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete list", role: .destructive) {
                    withAnimation { store.deleteList(list.id) }
                }
            } message: {
                Text("The films stay in your watchlist.")
            }
            .confirmationDialog("Clear “\(list.title)”?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear list", role: .destructive) {
                    withAnimation { store.clearRanking() }
                }
            }
        }
    }

    /// Menu per cambiare, creare e gestire le classifiche.
    @ViewBuilder
    private var listMenu: some View {
        @Bindable var store = store
        Picker("Lists", selection: $store.activeListID.animation()) {
            ForEach(store.lists) { list in
                Text(list.title)
                    .badge(list.movieIDs.count)
                    .tag(list.id)
            }
        }
        Section {
            Button("New list", systemImage: "plus") { openEditor(.create) }
            Button("Rename list", systemImage: "pencil") { openEditor(.rename) }
            Button("Clear list", systemImage: "xmark.circle") { confirmClear = true }
                .disabled(store.activeList.movieIDs.isEmpty)
            if store.lists.count > 1 {
                Button("Delete list", systemImage: "trash", role: .destructive) { confirmDelete = true }
            }
        }
    }

    private func openEditor(_ editor: NameEditor) {
        draftName = editor == .rename ? store.activeList.title : ""
        nameEditor = editor
    }

    private func saveName() {
        let name = draftName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        withAnimation {
            switch nameEditor {
            case .create: store.createList(named: name)
            case .rename: store.renameList(store.activeListID, to: name)
            case nil: break
            }
        }
    }
}
