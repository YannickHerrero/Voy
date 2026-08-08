import SwiftData
import SwiftUI

struct InventoryView: View {
    @Query(sort: \InventoryItem.modifiedAt, order: .reverse) private var items: [InventoryItem]
    @Query(sort: \InventoryCategory.sortOrder) private var categories: [InventoryCategory]
    @Query(sort: \InventoryCollection.name) private var collections: [InventoryCollection]

    @State private var searchText = ""
    @State private var selectedCategoryID: UUID?
    @State private var selectedCollectionID: UUID?
    @State private var selectedStatus: ItemStatus? = .owned

    private let columns = [GridItem(.adaptive(minimum: 142, maximum: 230), spacing: 20)]

    private var filter: InventoryFilter {
        InventoryFilter(
            searchText: searchText,
            categoryID: selectedCategoryID,
            collectionID: selectedCollectionID,
            status: selectedStatus
        )
    }

    private var filteredItems: [InventoryItem] {
        items.filter { filter.includes($0.summaryInput) }
    }

    private var hasFilters: Bool {
        !searchText.isEmpty || selectedCategoryID != nil || selectedCollectionID != nil || selectedStatus != .owned
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "A lighter life starts here",
                    systemImage: "square.grid.2x2",
                    description: Text("Add a possession with a photo, name, and category.")
                )
            } else if filteredItems.isEmpty {
                ContentUnavailableView {
                    Label("Nothing found", systemImage: "magnifyingglass")
                } description: {
                    Text("Try changing your search or filters.")
                } actions: {
                    Button("Clear Filters", action: clearFilters)
                }
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
                    .padding(.horizontal)
                    .padding(.vertical, 14)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle("Inventory")
        .searchable(text: $searchText, prompt: "Search possessions")
        .safeAreaInset(edge: .top, spacing: 0) {
            InventoryFilterBar(
                categories: categories,
                collections: collections,
                selectedCategoryID: $selectedCategoryID,
                selectedCollectionID: $selectedCollectionID,
                selectedStatus: $selectedStatus,
                hasFilters: hasFilters,
                clearFilters: clearFilters
            )
        }
    }

    private func clearFilters() {
        searchText = ""
        selectedCategoryID = nil
        selectedCollectionID = nil
        selectedStatus = .owned
    }
}

private struct InventoryGridCell: View {
    let item: InventoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            StoredImageView(data: item.thumbnailData ?? item.imageData, symbol: "shippingbox")
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(item.name)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            if item.quantity > 1 || item.status != .owned {
                HStack(spacing: 8) {
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                    }
                    if item.status != .owned {
                        Label(item.status.title, systemImage: item.status.symbol)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens item details")
    }
}

private struct InventoryFilterBar: View {
    let categories: [InventoryCategory]
    let collections: [InventoryCollection]
    @Binding var selectedCategoryID: UUID?
    @Binding var selectedCollectionID: UUID?
    @Binding var selectedStatus: ItemStatus?
    let hasFilters: Bool
    let clearFilters: () -> Void

    private var categoryTitle: String {
        categories.first { $0.id == selectedCategoryID }?.name ?? "Category"
    }

    private var collectionTitle: String {
        collections.first { $0.id == selectedCollectionID }?.name ?? "Collection"
    }

    private var statusTitle: String {
        selectedStatus?.title ?? "Any status"
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button("Any Category") { selectedCategoryID = nil }
                    Divider()
                    ForEach(categories) { category in
                        Button {
                            selectedCategoryID = category.id
                        } label: {
                            if selectedCategoryID == category.id {
                                Label(category.name, systemImage: "checkmark")
                            } else {
                                Text(category.name)
                            }
                        }
                    }
                } label: {
                    FilterLabel(title: categoryTitle, symbol: "square.grid.2x2")
                }

                Menu {
                    Button("Any Collection") { selectedCollectionID = nil }
                    Divider()
                    ForEach(collections) { collection in
                        Button {
                            selectedCollectionID = collection.id
                        } label: {
                            if selectedCollectionID == collection.id {
                                Label(collection.name, systemImage: "checkmark")
                            } else {
                                Text(collection.name)
                            }
                        }
                    }
                } label: {
                    FilterLabel(title: collectionTitle, symbol: "rectangle.stack")
                }

                Menu {
                    Button("Any Status") { selectedStatus = nil }
                    Divider()
                    ForEach(ItemStatus.allCases) { status in
                        Button {
                            selectedStatus = status
                        } label: {
                            if selectedStatus == status {
                                Label(status.title, systemImage: "checkmark")
                            } else {
                                Text(status.title)
                            }
                        }
                    }
                } label: {
                    FilterLabel(title: statusTitle, symbol: selectedStatus?.symbol ?? "circle.dotted")
                }

                if hasFilters {
                    Button("Reset", action: clearFilters)
                        .font(.subheadline)
                        .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}

private struct FilterLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.quaternary, in: Capsule())
    }
}
