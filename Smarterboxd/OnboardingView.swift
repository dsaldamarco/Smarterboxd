import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @Environment(WatchlistStore.self) private var store

    @State private var username = ""
    @State private var errorMessage: String?
    @State private var isImporting = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Text(verbatim: "Smarterboxd")
                        .font(.custom("SharpGrotesk-SemiBold20", size: 44, relativeTo: .largeTitle))
                    Text("Your Letterboxd watchlist,\nsorted, ranked and shuffled.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "at")
                            .foregroundStyle(.secondary)
                        TextField("Letterboxd username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .submitLabel(.go)
                            .focused($fieldFocused)
                            .onSubmit(connect)
                    }
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .glassEffect(.regular.interactive(), in: .capsule)

                    Button(action: connect) {
                        Group {
                            if store.isSyncing {
                                ProgressView().tint(.white)
                            } else {
                                Text("Load watchlist")
                            }
                        }
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || store.isSyncing)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Text("Your watchlist must be public.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        VStack { Divider() }
                        Text("or").font(.footnote).foregroundStyle(.tertiary)
                        VStack { Divider() }
                    }
                    .padding(.vertical, 6)

                    Button {
                        isImporting = true
                    } label: {
                        Label("Import watchlist.csv", systemImage: "doc.badge.arrow.up")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .disabled(store.isSyncing)

                    Text("From Letterboxd › Settings › Data › Export your data.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 440)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .animation(.smooth, value: errorMessage)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            do {
                try store.importCSV(from: result.get())
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func connect() {
        guard !store.isSyncing else { return }
        fieldFocused = false
        errorMessage = nil
        Task {
            do {
                try await store.connect(username: username)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Sfondo con i colori di Letterboxd, molto sfumati.
struct AmbientBackground: View {
    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.6, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                .orange.opacity(0.35), .clear, .green.opacity(0.25),
                .clear, .clear, .clear,
                .cyan.opacity(0.25), .clear, .orange.opacity(0.15),
            ]
        )
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
}
