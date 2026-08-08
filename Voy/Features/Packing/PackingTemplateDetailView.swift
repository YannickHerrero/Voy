import SwiftData
import SwiftUI

struct PackingTemplateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [PackingTemplateEntry]
    @Query private var items: [InventoryItem]

    let template: PackingTemplate
    @State private var showsItemPicker = false
    @State private var showsSessionStarter = false
    @State private var showsRename = false
    @State private var renameText = ""
    @State private var confirmsDeletion = false
    @State private var errorMessage: String?

    init(template: PackingTemplate) {
        self.template = template
        let id = template.id
        _entries = Query(
            filter: #Predicate<PackingTemplateEntry> { $0.templateID == id },
            sort: \PackingTemplateEntry.createdAt
        )
    }

    private var selectedItemIDs: Set<UUID> {
        Set(entries.map(\.itemID))
    }

    private var progress: PackingProgress {
        PackingCalculations.progress(for: entries.compactMap { entry in
            guard let item = item(for: entry) else { return nil }
            return PackingMetricInput(
                quantity: entry.quantity,
                weightGramsPerUnit: item.weightGrams,
                isPacked: false
            )
        })
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 28) {
                    metric(value: progress.totalUnits.formatted(), label: "Items")
                    if progress.knownTotalWeightGrams > 0 {
                        metric(
                            value: WeightFormatting.string(grams: progress.knownTotalWeightGrams),
                            label: progress.entriesWithoutWeight > 0 ? "Known weight" : "Total weight"
                        )
                    }
                }
                .padding(.vertical, 8)
            }

            if !entries.isEmpty {
                Section {
                    Button {
                        showsSessionStarter = true
                    } label: {
                        Label("Start Packing Session", systemImage: "checklist")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Empty Template",
                        systemImage: "suitcase",
                        description: Text("Add possessions from Inventory. You can reuse this list for every trip.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(entries) { entry in
                        entryRow(entry)
                            .swipeActions {
                                Button("Remove", systemImage: "trash", role: .destructive) {
                                    remove(entry)
                                }
                            }
                    }
                }

                Button {
                    showsItemPicker = true
                } label: {
                    Label("Add Inventory Items", systemImage: "plus")
                }
            } header: {
                Text("Packing List")
            } footer: {
                if progress.entriesWithoutWeight > 0 {
                    Text("Total weight excludes \(progress.entriesWithoutWeight) entries without weight data.")
                }
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Rename", systemImage: "pencil") {
                        renameText = template.name
                        showsRename = true
                    }
                    Button("Delete Template", systemImage: "trash", role: .destructive) {
                        confirmsDeletion = true
                    }
                } label: {
                    Label("Template Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showsItemPicker) {
            InventoryItemPickerView(excludingIDs: selectedItemIDs) { selectedItems in
                add(selectedItems)
            }
        }
        .sheet(isPresented: $showsSessionStarter) {
            StartPackingSessionView(template: template)
        }
        .alert("Rename Template", isPresented: $showsRename) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save", action: rename)
                .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .confirmationDialog(
            "Delete \(template.name)?",
            isPresented: $confirmsDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Template", role: .destructive, action: deleteTemplate)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Past packing sessions will not be affected.")
        }
        .alert("Couldn’t Save Changes", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private func entryRow(_ entry: PackingTemplateEntry) -> some View {
        HStack(spacing: 12) {
            if let item = item(for: entry) {
                StoredImageView(data: item.thumbnailData ?? item.imageData, symbol: "shippingbox")
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                    if item.status != .owned {
                        Text(item.status.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .frame(width: 52, height: 52)
                    .foregroundStyle(.secondary)
                Text("Unavailable item")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Stepper(
                "Quantity",
                value: Binding(
                    get: { entry.quantity },
                    set: { newValue in
                        entry.quantity = max(1, newValue)
                        template.modifiedAt = Date()
                        saveContext()
                    }
                ),
                in: 1...max(1, max(entry.quantity, item(for: entry)?.quantity ?? 1))
            )
            .labelsHidden()

            Text("×\(entry.quantity)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 32, alignment: .trailing)
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func item(for entry: PackingTemplateEntry) -> InventoryItem? {
        items.first { $0.id == entry.itemID }
    }

    private func add(_ selectedItems: [InventoryItem]) {
        for item in selectedItems {
            modelContext.insert(PackingTemplateEntry(templateID: template.id, itemID: item.id))
        }
        template.modifiedAt = Date()
        saveContext()
    }

    private func remove(_ entry: PackingTemplateEntry) {
        modelContext.delete(entry)
        template.modifiedAt = Date()
        saveContext()
    }

    private func rename() {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        template.name = name
        template.modifiedAt = Date()
        saveContext()
    }

    private func deleteTemplate() {
        entries.forEach(modelContext.delete)
        modelContext.delete(template)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "The template was not deleted. Try again later."
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "Your change could not be saved."
        }
    }
}
