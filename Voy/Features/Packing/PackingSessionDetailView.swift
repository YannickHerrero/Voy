import SwiftData
import SwiftUI

struct PackingSessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [PackingSessionEntry]
    @Query private var items: [InventoryItem]

    let session: PackingSession
    @State private var showsItemPicker = false
    @State private var confirmsReset = false
    @State private var errorMessage: String?

    init(session: PackingSession) {
        self.session = session
        let id = session.id
        _entries = Query(
            filter: #Predicate<PackingSessionEntry> { $0.sessionID == id },
            sort: \PackingSessionEntry.sortOrder
        )
    }

    private var progress: PackingProgress {
        PackingCalculations.progress(for: entries.map(\.metricInput))
    }

    private var selectedItemIDs: Set<UUID> {
        Set(entries.compactMap(\.itemID))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(progress.packedUnits) / \(progress.totalUnits)")
                            .font(.title.weight(.semibold).monospacedDigit())
                        Text("packed")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    ProgressView(value: progress.fractionComplete)
                        .tint(progress.fractionComplete == 1 ? .green : .accentColor)

                    if progress.knownTotalWeightGrams > 0 {
                        Text("\(WeightFormatting.string(grams: progress.packedWeightGrams)) / \(WeightFormatting.string(grams: progress.knownTotalWeightGrams)) packed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "checklist",
                        description: Text("Add an existing possession for this trip.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(entries) { entry in
                        Button {
                            togglePacked(entry)
                        } label: {
                            entryRow(entry)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                remove(entry)
                            }
                        }
                    }
                }

                if session.state != .archived {
                    Button {
                        showsItemPicker = true
                    } label: {
                        Label("Add Inventory Item", systemImage: "plus")
                    }
                }
            } header: {
                Text("Checklist")
            } footer: {
                if progress.entriesWithoutWeight > 0 {
                    Text("Weight excludes \(progress.entriesWithoutWeight) entries without weight data.")
                }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    switch session.state {
                    case .active:
                        Button("Complete Session", systemImage: "checkmark.circle") {
                            setState(.completed)
                        }
                        Button("Reset Packed Items", systemImage: "arrow.counterclockwise") {
                            confirmsReset = true
                        }
                    case .completed:
                        Button("Reopen Session", systemImage: "arrow.uturn.backward") {
                            setState(.active)
                        }
                        Button("Archive Session", systemImage: "archivebox") {
                            setState(.archived)
                        }
                    case .archived:
                        Button("Reopen Session", systemImage: "arrow.uturn.backward") {
                            setState(.active)
                        }
                    }
                } label: {
                    Label("Session Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showsItemPicker) {
            InventoryItemPickerView(excludingIDs: selectedItemIDs) { selectedItems in
                add(selectedItems)
            }
        }
        .confirmationDialog("Reset all packed items?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive, action: resetPackedItems)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The trip and its item list will remain available.")
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

    private func entryRow(_ entry: PackingSessionEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.isPacked ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(entry.isPacked ? Color.green : .secondary)

            StoredImageView(data: entry.thumbnailSnapshot, symbol: "shippingbox")
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.itemNameSnapshot)
                    .foregroundStyle(.primary)
                    .strikethrough(entry.isPacked, color: .secondary)
                if let itemID = entry.itemID, !items.contains(where: { $0.id == itemID }) {
                    Label("No longer in Inventory", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if entry.quantity > 1 {
                Text("×\(entry.quantity)")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(entry.isPacked ? "Packed" : "Not packed")
    }

    private func togglePacked(_ entry: PackingSessionEntry) {
        guard session.state != .archived else { return }
        entry.isPacked.toggle()
        session.modifiedAt = Date()
        saveContext()
    }

    private func add(_ selectedItems: [InventoryItem]) {
        var nextOrder = (entries.map(\.sortOrder).max() ?? -1) + 1
        for item in selectedItems {
            PackingSessionFactory.add(item: item, to: session, sortOrder: nextOrder, in: modelContext)
            nextOrder += 1
        }
        saveContext()
    }

    private func remove(_ entry: PackingSessionEntry) {
        modelContext.delete(entry)
        session.modifiedAt = Date()
        saveContext()
    }

    private func resetPackedItems() {
        entries.forEach { $0.isPacked = false }
        session.modifiedAt = Date()
        saveContext()
    }

    private func setState(_ state: PackingSessionState) {
        session.state = state
        session.modifiedAt = Date()
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "Your change could not be saved. The checklist will refresh from its last saved state."
        }
    }
}
