import SwiftData
import SwiftUI

struct AppTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var selection: AppTab

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let requestedTab = arguments.firstIndex(of: "-InitialTab")
            .flatMap { index in arguments.indices.contains(index + 1) ? AppTab(rawValue: arguments[index + 1]) : nil }
        _selection = State(initialValue: requestedTab ?? .inventory)
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                InventoryView()
            }
            .tabItem {
                Label("Inventory", systemImage: "square.grid.2x2")
            }
            .tag(AppTab.inventory)

            NavigationStack {
                PackingView()
            }
            .tabItem {
                Label("Packing", systemImage: "suitcase")
            }
            .tag(AppTab.packing)

            NavigationStack {
                MinimalismView()
            }
            .tabItem {
                Label("Minimalism", systemImage: "leaf")
            }
            .tag(AppTab.minimalism)
        }
        .tabViewStyle(.sidebarAdaptable)
        .safeAreaInset(edge: .top, spacing: 0) {
            SyncStatusBanner()
        }
        .task {
            appState.bootstrapIfNeeded(using: modelContext)
            await appState.refreshCloudStatus()
        }
    }
}

private enum AppTab: String {
    case inventory
    case packing
    case minimalism
}

#Preview {
    let state = AppState()
    AppTabView()
        .environment(state)
        .modelContainer(state.modelContainer)
}
