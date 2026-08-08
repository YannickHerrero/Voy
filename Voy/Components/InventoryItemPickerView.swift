import SwiftData
import SwiftUI

struct InventoryItemPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]

    let excludingIDs: Set<UUID>
    let onAdd: ([InventoryItem]) -> Void
    @State private var selection: Set<UUID> = []
    @State private var searchText = ""

    private var availableItems: [InventoryItem] {
        items.filter { item in
            item.status == .owned
                && !excludingIDs.contains(item.id)
                && (searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availableItems.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Available Items" : "Nothing Found",
                        systemImage: searchText.isEmpty ? "shippingbox" : "magnifyingglass",
                        description: Text(searchText.isEmpty
                                          ? "Add owned possessions to Inventory first."
                                          : "Try another search.")
                    )
                } else {
                    List(availableItems) { item in
                        Button {
                            if selection.contains(item.id) {
                                selection.remove(item.id)
                            } else {
                                selection.insert(item.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                StoredImageView(data: item.thumbnailData ?? item.imageData, symbol: "shippingbox")
                                    .frame(width: 52, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .foregroundStyle(.primary)
                                    if item.quantity > 1 {
                                        Text("\(item.quantity) available")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: selection.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection.contains(item.id) ? Color.accentColor : .secondary)
                                    .font(.title3)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(selection.contains(item.id) ? "Selected" : "Not selected")
                    }
                }
            }
            .navigationTitle("Add Inventory Items")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search owned items")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(items.filter { selection.contains($0.id) })
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selection.isEmpty)
                }
            }
        }
    }
}
