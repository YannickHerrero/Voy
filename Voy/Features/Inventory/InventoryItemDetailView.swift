import SwiftData
import SwiftUI

struct InventoryItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryCategory.sortOrder) private var categories: [InventoryCategory]
    @Query(sort: \InventoryCollection.name) private var collections: [InventoryCollection]

    let item: InventoryItem
    @State private var showsEditor = false
    @State private var errorMessage: String?

    private var categoryName: String {
        categories.first { $0.id == item.categoryID }?.name ?? "Uncategorized"
    }

    private var itemCollections: [InventoryCollection] {
        collections.filter { item.collectionIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StoredImageView(data: item.imageData ?? item.thumbnailData, symbol: "shippingbox")
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text(item.name)
                        .font(.title2.weight(.semibold))

                    Label(item.status.title, systemImage: item.status.symbol)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if item.quantity > 1 || item.weightGrams != nil {
                    Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 10) {
                        if item.quantity > 1 {
                            GridRow {
                                Text("Quantity").foregroundStyle(.secondary)
                                Text(item.quantity.formatted())
                            }
                        }
                        if let weightGrams = item.weightGrams {
                            GridRow {
                                Text("Weight").foregroundStyle(.secondary)
                                Text(formattedWeight(weightGrams))
                            }
                        }
                    }
                    .font(.body)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(categoryName)
                }

                if !itemCollections.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Collections")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(itemCollections) { collection in
                                    Text(collection.name)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(.quaternary, in: Capsule())
                                }
                            }
                        }
                    }
                }

                if let description = item.itemDescription, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(description)
                            .foregroundStyle(.secondary)
                    }
                }

                if let sourceURL = item.sourceURL {
                    Link(destination: sourceURL) {
                        Label("View Source", systemImage: "safari")
                    }
                    .font(.subheadline)
                }

                statusActions
                    .padding(.top, 8)
            }
            .frame(maxWidth: 700, alignment: .leading)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showsEditor = true }
            }
        }
        .sheet(isPresented: $showsEditor) {
            InventoryItemEditorView(item: item)
        }
        .alert("Couldn’t Update Item", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    @ViewBuilder
    private var statusActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch item.status {
            case .owned:
                Button {
                    setStatus(.outgoing)
                } label: {
                    Label("Mark as Outgoing", systemImage: ItemStatus.outgoing.symbol)
                }
            case .outgoing:
                Button {
                    setStatus(.owned)
                } label: {
                    Label("Keep Item", systemImage: ItemStatus.owned.symbol)
                }

                Button {
                    setStatus(.archived)
                } label: {
                    Label("Archive Item", systemImage: ItemStatus.archived.symbol)
                }
            case .archived:
                Button {
                    setStatus(.owned)
                } label: {
                    Label("Restore to Inventory", systemImage: "arrow.uturn.backward")
                }
            }
        }
        .buttonStyle(.bordered)
    }

    private func setStatus(_ status: ItemStatus) {
        let previousStatus = item.status
        item.status = status
        item.touch()
        do {
            try modelContext.save()
        } catch {
            item.status = previousStatus
            errorMessage = "The change could not be saved. Your previous status was restored."
        }
    }

    private func formattedWeight(_ grams: Double) -> String {
        if grams < 1_000 {
            return "\(grams.formatted(.number.precision(.fractionLength(0)))) g"
        }
        return "\((grams / 1_000).formatted(.number.precision(.fractionLength(0...2)))) kg"
    }
}
