import SwiftData
import SwiftUI

struct InventoryItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryCategory.sortOrder) private var categories: [InventoryCategory]
    @Query(sort: \InventoryCollection.name) private var collections: [InventoryCollection]

    let item: InventoryItem?
    @State private var draft: Draft
    @State private var showsMoreDetails: Bool
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    init(item: InventoryItem? = nil) {
        self.item = item
        let draft = Draft(item: item)
        _draft = State(initialValue: draft)
        _showsMoreDetails = State(initialValue: item != nil && draft.hasOptionalDetails)
    }

    private enum Field {
        case name
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.categoryID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    StoredImageView(data: draft.imageData ?? draft.thumbnailData, symbol: "camera")
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 360)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.done)
                        .accessibilityLabel("Item name")

                    Picker("Category", selection: $draft.categoryID) {
                        Text("Choose a category").tag(nil as UUID?)
                        ForEach(categories) { category in
                            Text(category.name).tag(category.id as UUID?)
                        }
                    }
                }

                Section {
                    DisclosureGroup("More details", isExpanded: $showsMoreDetails) {
                        Picker("Status", selection: $draft.status) {
                            ForEach(ItemStatus.allCases) { status in
                                Label(status.title, systemImage: status.symbol).tag(status)
                            }
                        }

                        Stepper("Quantity: \(draft.quantity)", value: $draft.quantity, in: 1...9_999)

                        LabeledContent("Weight") {
                            TextField("kg", text: $draft.weightKilograms)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 110)
                                .accessibilityLabel("Weight in kilograms")
                        }

                        if !collections.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Collections")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                ForEach(collections) { collection in
                                    Toggle(
                                        collection.name,
                                        isOn: Binding(
                                            get: { draft.collectionIDs.contains(collection.id) },
                                            set: { isSelected in
                                                if isSelected {
                                                    draft.collectionIDs.insert(collection.id)
                                                } else {
                                                    draft.collectionIDs.remove(collection.id)
                                                }
                                            }
                                        )
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        TextField("Description", text: $draft.itemDescription, axis: .vertical)
                            .lineLimit(3...8)
                    }
                }
            }
            .navigationTitle(item == nil ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .alert("Couldn’t Save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
            .onAppear {
                if item == nil {
                    draft.categoryID = draft.categoryID ?? categories.first?.id
                    focusedField = .name
                }
            }
        }
    }

    private func save() {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let categoryID = draft.categoryID else { return }

        let target = item ?? InventoryItem(name: trimmedName)
        target.name = trimmedName
        target.categoryID = categoryID
        target.status = draft.status
        target.quantity = max(1, draft.quantity)
        target.weightGrams = parsedWeightGrams
        let trimmedDescription = draft.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        target.itemDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
        target.collectionIDs = Array(draft.collectionIDs)
        target.imageData = draft.imageData
        target.thumbnailData = draft.thumbnailData
        target.originalImageData = draft.originalImageData
        target.touch()

        if item == nil {
            modelContext.insert(target)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Your item is still on screen. Check your connection and try saving again."
        }
    }

    private var parsedWeightGrams: Double? {
        let normalized = draft.weightKilograms.replacingOccurrences(of: ",", with: ".")
        guard let kilograms = Double(normalized), kilograms >= 0 else { return nil }
        return kilograms * 1_000
    }
}

private extension InventoryItemEditorView {
    struct Draft {
        var name: String
        var categoryID: UUID?
        var status: ItemStatus
        var quantity: Int
        var weightKilograms: String
        var itemDescription: String
        var collectionIDs: Set<UUID>
        var imageData: Data?
        var thumbnailData: Data?
        var originalImageData: Data?

        init(item: InventoryItem?) {
            name = item?.name ?? ""
            categoryID = item?.categoryID
            status = item?.status ?? .owned
            quantity = item?.quantity ?? 1
            if let grams = item?.weightGrams {
                weightKilograms = (grams / 1_000).formatted(.number.precision(.fractionLength(0...3)))
            } else {
                weightKilograms = ""
            }
            itemDescription = item?.itemDescription ?? ""
            collectionIDs = Set(item?.collectionIDs ?? [])
            imageData = item?.imageData
            thumbnailData = item?.thumbnailData
            originalImageData = item?.originalImageData
        }

        var hasOptionalDetails: Bool {
            status != .owned || quantity != 1 || !weightKilograms.isEmpty
                || !itemDescription.isEmpty || !collectionIDs.isEmpty
        }
    }
}
