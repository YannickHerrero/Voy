import SwiftData
import SwiftUI

struct InventoryTaxonomyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryCategory.sortOrder) private var categories: [InventoryCategory]
    @Query(sort: \InventoryCollection.name) private var collections: [InventoryCollection]
    @Query private var items: [InventoryItem]
    @Query private var settings: [MinimalismSettings]

    @State private var editorRequest: EditorRequest?
    @State private var deletionRequest: DeletionRequest?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        taxonomyRow(
                            name: category.name,
                            usage: categoryUsage(category.id),
                            edit: { editorRequest = EditorRequest(kind: .category, id: category.id, name: category.name) },
                            delete: { requestDeletion(kind: .category, id: category.id, name: category.name) }
                        )
                    }
                } header: {
                    Text("Categories")
                } footer: {
                    Text("A category describes what an object is. Categories in use cannot be deleted.")
                }

                Section {
                    ForEach(collections) { collection in
                        collectionRow(collection)
                    }
                } header: {
                    Text("Collections")
                } footer: {
                    Text("A collection describes where or how possessions belong in your life.")
                }
            }
            .navigationTitle("Organize Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            editorRequest = EditorRequest(kind: .category, id: nil, name: "")
                        } label: {
                            Label("New Category", systemImage: "square.grid.2x2")
                        }

                        Button {
                            editorRequest = EditorRequest(kind: .collection, id: nil, name: "")
                        } label: {
                            Label("New Collection", systemImage: "rectangle.stack")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .alert(editorRequest?.title ?? "Edit", isPresented: Binding(
                get: { editorRequest != nil },
                set: { if !$0 { editorRequest = nil } }
            )) {
                TextField("Name", text: Binding(
                    get: { editorRequest?.name ?? "" },
                    set: { editorRequest?.name = $0 }
                ))
                Button("Cancel", role: .cancel) { editorRequest = nil }
                Button("Save") { saveEditorRequest() }
                    .disabled(editorRequest?.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            } message: {
                Text(editorRequest?.kind.helpText ?? "")
            }
            .confirmationDialog(
                "Remove \(deletionRequest?.name ?? "")?",
                isPresented: Binding(
                    get: { deletionRequest != nil },
                    set: { if !$0 { deletionRequest = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) { performDeletion() }
                Button("Cancel", role: .cancel) { deletionRequest = nil }
            } message: {
                if deletionRequest?.kind == .collection {
                    Text("Items stay in Inventory and will simply leave this collection.")
                }
            }
            .alert("Couldn’t Make That Change", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private func collectionRow(_ collection: InventoryCollection) -> some View {
        let edit = {
            editorRequest = EditorRequest(
                kind: .collection,
                id: collection.id,
                name: collection.name
            )
        }
        let delete = {
            requestDeletion(kind: .collection, id: collection.id, name: collection.name)
        }

        return HStack {
            NavigationLink {
                InventoryCollectionDetailView(collection: collection)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(collection.name)
                    let usage = collectionUsage(collection.id)
                    Text("\(usage) \(usage == 1 ? "item" : "items")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Rename", systemImage: "pencil", action: edit)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            Button("Remove", systemImage: "trash", action: delete)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
        }
        .contextMenu {
            Button("Rename", systemImage: "pencil", action: edit)
            Button("Remove", systemImage: "trash", role: .destructive, action: delete)
        }
    }

    private func taxonomyRow(
        name: String,
        usage: Int,
        edit: @escaping () -> Void,
        delete: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                Text("\(usage) \(usage == 1 ? "item" : "items")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Rename", systemImage: "pencil", action: edit)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            Button("Remove", systemImage: "trash", action: delete)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
        }
        .contextMenu {
            Button("Rename", systemImage: "pencil", action: edit)
            Button("Remove", systemImage: "trash", role: .destructive, action: delete)
        }
    }

    private func categoryUsage(_ id: UUID) -> Int {
        items.lazy.filter { $0.categoryID == id }.reduce(0) { $0 + max(1, $1.quantity) }
    }

    private func collectionUsage(_ id: UUID) -> Int {
        items.lazy.filter { $0.collectionIDs.contains(id) }.reduce(0) { $0 + max(1, $1.quantity) }
    }

    private func requestDeletion(kind: TaxonomyKind, id: UUID, name: String) {
        if kind == .category {
            guard categories.count > 1 else {
                errorMessage = "Keep at least one category so every possession has somewhere to belong."
                return
            }
            guard categoryUsage(id) == 0 else {
                errorMessage = "Move items out of \(name) before removing this category."
                return
            }
        }
        deletionRequest = DeletionRequest(kind: kind, id: id, name: name)
    }

    private func saveEditorRequest() {
        guard let request = editorRequest else { return }
        let name = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let existingNames = request.kind == .category
            ? categories.filter { $0.id != request.id }.map(\.name)
            : collections.filter { $0.id != request.id }.map(\.name)
        guard !existingNames.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
            editorRequest = nil
            errorMessage = "That name is already in use."
            return
        }

        switch request.kind {
        case .category:
            if let id = request.id, let category = categories.first(where: { $0.id == id }) {
                category.name = name
            } else {
                let nextOrder = (categories.map(\.sortOrder).max() ?? -1) + 1
                modelContext.insert(InventoryCategory(name: name, sortOrder: nextOrder))
            }
        case .collection:
            if let id = request.id, let collection = collections.first(where: { $0.id == id }) {
                collection.name = name
            } else {
                modelContext.insert(InventoryCollection(name: name))
            }
        }

        editorRequest = nil
        saveContext()
    }

    private func performDeletion() {
        guard let request = deletionRequest else { return }
        deletionRequest = nil

        switch request.kind {
        case .category:
            if let category = categories.first(where: { $0.id == request.id }) {
                modelContext.delete(category)
            }
        case .collection:
            for item in items where item.collectionIDs.contains(request.id) {
                item.collectionIDs.removeAll { $0 == request.id }
                item.touch()
            }
            for setting in settings where setting.nomadicCollectionID == request.id {
                setting.nomadicCollectionID = nil
                setting.modifiedAt = Date()
            }
            if let collection = collections.first(where: { $0.id == request.id }) {
                modelContext.delete(collection)
            }
        }
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "The change could not be saved. Nothing was removed."
        }
    }
}

private extension InventoryTaxonomyView {
    enum TaxonomyKind: Equatable {
        case category
        case collection

        var helpText: String {
            switch self {
            case .category: "What kind of object is it?"
            case .collection: "Where or how does it belong in your life?"
            }
        }
    }

    struct EditorRequest {
        let kind: TaxonomyKind
        let id: UUID?
        var name: String

        var title: String {
            if id == nil {
                return kind == .category ? "New Category" : "New Collection"
            }
            return kind == .category ? "Rename Category" : "Rename Collection"
        }
    }

    struct DeletionRequest {
        let kind: TaxonomyKind
        let id: UUID
        let name: String
    }
}
