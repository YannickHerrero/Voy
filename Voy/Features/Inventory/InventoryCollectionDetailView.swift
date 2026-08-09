import SwiftData
import SwiftUI

struct InventoryCollectionDetailView: View {
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let collection: InventoryCollection
    @State private var searchText = ""
    @State private var showsMembershipEditor = false

    private var matchingMembers: [InventoryItem] {
        items.filter { item in
            item.collectionIDs.contains(collection.id)
                && (searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var memberCount: Int {
        items.lazy.filter { $0.collectionIDs.contains(collection.id) }.count
    }

    private let columns = [GridItem(.adaptive(minimum: 142, maximum: 230), spacing: 20)]

    var body: some View {
        Group {
            if memberCount == 0 {
                ContentUnavailableView {
                    Label("No Items in \(collection.name)", systemImage: "rectangle.stack")
                } description: {
                    Text("Choose the possessions that belong in this collection.")
                } actions: {
                    Button("Manage Collection") { showsMembershipEditor = true }
                        .buttonStyle(.borderedProminent)
                }
            } else if matchingMembers.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 26) {
                        ForEach(matchingMembers) { item in
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
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search collection")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Manage", systemImage: "checklist") {
                    showsMembershipEditor = true
                }
            }
        }
        .sheet(isPresented: $showsMembershipEditor) {
            InventoryCollectionMembershipEditor(collection: collection)
                .collectionEditorPresentation(horizontalSizeClass: horizontalSizeClass)
        }
    }
}

private struct InventoryCollectionMembershipEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]

    let collection: InventoryCollection
    @State private var selection: Set<UUID> = []
    @State private var searchText = ""
    @State private var didLoadSelection = false
    @State private var errorMessage: String?

    private var matchingItems: [InventoryItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var ownedItems: [InventoryItem] {
        matchingItems.filter { $0.status == .owned }
    }

    private var otherItems: [InventoryItem] {
        matchingItems.filter { $0.status != .owned }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Inventory Items",
                        systemImage: "shippingbox",
                        description: Text("Add possessions to Inventory first.")
                    )
                } else if matchingItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        if !ownedItems.isEmpty {
                            Section("Owned") {
                                ForEach(ownedItems) { item in
                                    selectionRow(item)
                                }
                            }
                        }

                        if !otherItems.isEmpty {
                            Section("Other Statuses") {
                                ForEach(otherItems) { item in
                                    selectionRow(item)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage \(collection.name)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search all items")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Text("\(selection.count) selected")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button(searchText.isEmpty ? "Select All" : "Select Search Results") {
                            selection.formUnion(matchingItems.map(\.id))
                        }
                        Button("Clear All") {
                            selection.removeAll()
                        }
                    } label: {
                        Label("Selection Actions", systemImage: "ellipsis.circle")
                    }

                    Button("Save", action: save)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadSelectionIfNeeded)
            .alert("Couldn’t Update Collection", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private func selectionRow(_ item: InventoryItem) -> some View {
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

    private func loadSelectionIfNeeded() {
        guard !didLoadSelection else { return }
        didLoadSelection = true
        selection = Set(items.lazy.filter { $0.collectionIDs.contains(collection.id) }.map(\.id))
    }

    private func save() {
        let currentMemberIDs = items.lazy
            .filter { $0.collectionIDs.contains(collection.id) }
            .map(\.id)
        let changes = InventoryCollectionMembership.changes(
            availableItemIDs: items.map(\.id),
            currentMemberIDs: currentMemberIDs,
            selectedIDs: selection
        )

        guard !changes.isEmpty else {
            dismiss()
            return
        }

        for item in items where changes.addedIDs.contains(item.id) {
            if !item.collectionIDs.contains(collection.id) {
                item.collectionIDs.append(collection.id)
                item.touch()
            }
        }
        for item in items where changes.removedIDs.contains(item.id) {
            item.collectionIDs.removeAll { $0 == collection.id }
            item.touch()
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "The membership changes could not be saved. Nothing was changed."
        }
    }
}

private extension View {
    @ViewBuilder
    func collectionEditorPresentation(horizontalSizeClass: UserInterfaceSizeClass?) -> some View {
        if horizontalSizeClass == .compact {
            presentationDetents([.large])
                .presentationDragIndicator(.visible)
        } else {
            presentationSizing(.page)
        }
    }
}
