import SwiftData
import SwiftUI

struct VoyServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(VoySyncCoordinator.self) private var syncCoordinator

    @State private var serverURL = ""
    @State private var token = ""
    @State private var errorMessage: String?
    @State private var didLoad = false

    private var trimmedURL: String {
        serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validatedURL: URL? {
        guard let components = URLComponents(string: trimmedURL), let url = components.url else { return nil }
        guard components.user == nil, components.password == nil, components.query == nil, components.fragment == nil else {
            return nil
        }
        guard let host = components.host, !host.isEmpty else { return nil }
        let scheme = components.scheme?.lowercased()
        guard scheme == "https" || (scheme == "http" && host == "localhost") else { return nil }
        return url
    }

    private var canSave: Bool {
        validatedURL != nil && trimmedToken.count >= 32 && !syncCoordinator.isSyncing
    }

    var body: some View {
        Form {
            Section {
                TextField("https://voy.example.net", text: $serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                SecureField("Bearer token", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.password)
            } header: {
                Text("Private Mirror")
            } footer: {
                Text("Voy remains the source of truth. The server and web interface receive read-only snapshots. The token stays in this device’s Keychain.")
            }

            Section("Status") {
                statusRow
                if VoyServerConfiguration.lastSyncDate != nil {
                    Button("Upload Now") {
                        Task { await saveAndSync(dismissAfterSaving: false) }
                    }
                    .disabled(!canSave)
                }
            }

            if !VoyServerConfiguration.serverURLString.isEmpty {
                Section {
                    Button("Disable Server Mirror", role: .destructive, action: disable)
                }
            }
        }
        .navigationTitle("Server Mirror")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await saveAndSync(dismissAfterSaving: true) }
                }
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            serverURL = VoyServerConfiguration.serverURLString
            do {
                token = try VoyServerCredentials.token() ?? ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .alert("Server Mirror", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch syncCoordinator.state {
        case .disabled:
            Label("Not configured", systemImage: "server.rack")
                .foregroundStyle(.secondary)
        case .idle:
            Label("Ready", systemImage: "server.rack")
        case let .syncing(message):
            HStack {
                ProgressView()
                Text(message)
            }
        case let .synced(date):
            Label("Updated \(date.formatted(.relative(presentation: .named)))", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .failed(message):
            VStack(alignment: .leading, spacing: 4) {
                Label("Upload failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveAndSync(dismissAfterSaving: Bool) async {
        guard let validatedURL else {
            errorMessage = "Enter an HTTPS server URL. HTTP is accepted only for localhost development."
            return
        }
        guard trimmedToken.count >= 32 else {
            errorMessage = "The bearer token must contain at least 32 characters."
            return
        }

        do {
            VoyServerConfiguration.serverURLString = validatedURL.absoluteString
            try VoyServerCredentials.setToken(trimmedToken)
            await syncCoordinator.syncIfConfigured(using: modelContext, force: true)
            if case let .failed(message) = syncCoordinator.state {
                errorMessage = message
            } else if dismissAfterSaving {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func disable() {
        do {
            try VoyServerConfiguration.disable()
            syncCoordinator.markDisabled()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
