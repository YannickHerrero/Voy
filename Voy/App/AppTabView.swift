import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                PlaceholderView(
                    title: "Inventory",
                    symbol: "square.grid.2x2",
                    message: "Your possessions will appear here."
                )
                .navigationTitle("Inventory")
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
    AppTabView()
}
