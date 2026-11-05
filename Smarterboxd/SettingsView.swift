import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(WatchlistStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isImporting = false
    @State private var confirmClear = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Text(initial)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(.orange.gradient, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.headline)
                            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if store.source == .letterboxd {
                        Button {
                            Task { await store.refresh() }
                        } label: {
                            HStack {
                                Label("Sincronizza ora", systemImage: "arrow.triangle.2.circlepath")
                                Spacer()
                                if store.isSyncing { ProgressView() }
                            }
                        }
                        .disabled(store.isSyncing)
                    }
                } footer: {
                    if let lastSync = store.lastSync {
                        Text("Aggiornata \(lastSync.formatted(Date.RelativeFormatStyle(presentation: .named, locale: .italian))).")
                    }
                }

                Section("Watchlist") {
                    LabeledContent("Film", value: "\(store.visibleMovies.count)")
                    LabeledContent("In classifica", value: "\(store.rankedMovies.count)")
                    Button("Ripristina film nascosti (\(store.hiddenCount))") {
                        withAnimation { store.unhideAll() }
                    }
                    .disabled(store.hiddenCount == 0)
                    Button("Svuota classifica", role: .destructive) { confirmClear = true }
                        .disabled(store.rankedIDs.isEmpty)
                }

                Section {
                    Button("Importa watchlist.csv", systemImage: "doc.badge.arrow.up") { isImporting = true }
                    Button("Cambia account", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        dismiss()
                        store.signOut()
                    }
                } footer: {
                    if let importError { Text(importError).foregroundStyle(.red) }
                }

                Section {
                } footer: {
                    Text("Locandine, trame e crediti forniti da TMDb. Smarterboxd non è affiliata a Letterboxd.")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .confirmationDialog("Svuotare la classifica?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Svuota", role: .destructive) { store.clearRanking() }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                do {
                    try store.importCSV(from: result.get())
                    importError = nil
                } catch {
                    importError = error.localizedDescription
                }
            }
        }
    }

    private var title: String {
        switch store.source {
        case .letterboxd: store.displayName ?? store.username ?? "Letterboxd"
        default: "Watchlist importata"
        }
    }

    private var subtitle: String {
        switch store.source {
        case .letterboxd: "@\(store.username ?? "")"
        default: "Da file CSV"
        }
    }

    private var initial: String {
        String(title.first.map { String($0).uppercased() } ?? "S")
    }
}
