import SwiftUI

struct SyncStatusBanner: View {
    @Environment(AppState.self) private var appState

    private var message: String? {
        if let persistenceNotice = appState.persistenceNotice {
            return persistenceNotice
        }
        if case let .unavailable(message) = appState.cloudStatus {
            return message
        }
        return nil
    }

    var body: some View {
        if let message {
            Label(message, systemImage: "icloud.slash")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.thinMaterial)
                .accessibilityLabel("Sync notice. \(message)")
        }
    }
}
