import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(WatchlistStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isImporting = false
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
                                Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                                Spacer()
                                if store.isSyncing { ProgressView() }
                            }
                        }
                        .disabled(store.isSyncing)
                    }
                } footer: {
                    if let lastSync = store.lastSync {
                        Text("Updated \(lastSync.formatted(.relative(presentation: .named))).")
                    }
                }

                Section("Watchlist") {
                    LabeledContent("Films", value: store.visibleMovies.count.formatted())
                    LabeledContent("Lists", value: store.lists.count.formatted())
                    Button("Restore hidden films (\(store.hiddenCount))") {
                        withAnimation { store.unhideAll() }
                    }
                    .disabled(store.hiddenCount == 0)
                }

                Section {
                    Button("Import watchlist.csv", systemImage: "doc.badge.arrow.up") { isImporting = true }
                    Button("Change account", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        dismiss()
                        store.signOut()
                    }
                } footer: {
                    if let importError { Text(importError).foregroundStyle(.red) }
                }

                Section {
                } footer: {
                    Text("Posters, synopses and credits provided by TMDb. Smarterboxd is not affiliated with Letterboxd.")
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
        default: String(localized: "Imported watchlist")
        }
    }

    private var subtitle: String {
        switch store.source {
        case .letterboxd: "@\(store.username ?? "")"
        default: String(localized: "From CSV file")
        }
    }

    private var initial: String {
        String(title.first.map { String($0).uppercased() } ?? "S")
    }
}
