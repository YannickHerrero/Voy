import SwiftData
import SwiftUI

struct InventorySubsetView: View {
    @Query(sort: \InventoryItem.modifiedAt, order: .reverse) private var items: [InventoryItem]

    let title: String
    let baseFilter: InventoryFilter
    @State private var searchText = ""
    private let columns = [GridItem(.adaptive(minimum: 142, maximum: 230), spacing: 20)]

    private var filteredItems: [InventoryItem] {
        var filter = baseFilter
        filter.searchText = searchText
        return items.filter { filter.includes($0.summaryInput) }
    }

    var body: some View {
        Group {
            if filteredItems.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Items" : "Nothing Found",
                    systemImage: searchText.isEmpty ? "shippingbox" : "magnifyingglass",
                    description: Text(searchText.isEmpty
                                      ? "No possessions currently match this view."
                                      : "Try another search.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 26) {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                InventoryItemDetailView(item: item)
                            } label: {
                                InventoryGridCell(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search this view")
    }
}
