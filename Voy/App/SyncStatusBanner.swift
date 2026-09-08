import SwiftUI

struct SyncStatusBanner: View {
    @Environment(AppState.self) private var appState
    @Environment(VoySyncCoordinator.self) private var syncCoordinator

    private var notice: (message: String, symbol: String)? {
        if let persistenceNotice = appState.persistenceNotice {
            return (persistenceNotice, "icloud.slash")
        }
        if case let .failed(message) = syncCoordinator.state {
            return ("Server mirror: \(message)", "arrow.triangle.2.circlepath.icloud")
        }
        if case let .unavailable(message) = appState.cloudStatus {
            return (message, "icloud.slash")
        }
        return nil
    }

    var body: some View {
        if let notice {
            Label(notice.message, systemImage: notice.symbol)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.thinMaterial)
                .accessibilityLabel("Sync notice. \(notice.message)")
        }
    }
}
