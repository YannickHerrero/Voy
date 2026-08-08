import SwiftData
import SwiftUI

struct AppTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            NavigationStack {
                InventoryView()
            }
            .tabItem {
                Label("Inventory", systemImage: "square.grid.2x2")
            }

            NavigationStack {
                PlaceholderView(
                    title: "Packing",
                    symbol: "suitcase",
                    message: "Reusable lists and trips will appear here."
                )
                .navigationTitle("Packing")
            }
            .tabItem {
                Label("Packing", systemImage: "suitcase")
            }

            NavigationStack {
                PlaceholderView(
                    title: "Minimalism",
                    symbol: "leaf",
                    message: "A calm view of what you own."
                )
                .navigationTitle("Minimalism")
            }
            .tabItem {
                Label("Minimalism", systemImage: "leaf")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            SyncStatusBanner()
        }
        .task {
            appState.bootstrapIfNeeded(using: modelContext)
            await appState.refreshCloudStatus()
        }
    }
}

private struct PlaceholderView: View {
    let title: String
    let symbol: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
    }
}

#Preview {
    let state = AppState()
    AppTabView()
        .environment(state)
        .modelContainer(state.modelContainer)
}
