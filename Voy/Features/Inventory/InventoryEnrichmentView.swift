import SwiftData
import SwiftUI

struct InventoryEnrichmentView: View {
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Query(sort: \InventoryCategory.sortOrder) private var categories: [InventoryCategory]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("inventoryEnrichment.selectedField") private var selectedFieldRawValue = InventoryDetailField.weight.rawValue
    @State private var searchText = ""
    @State private var editorRequest: EditorRequest?
#if DEBUG
    @State private var didPresentDebugEditor = false
#endif

    private var selectedField: InventoryDetailField {
        InventoryDetailField(rawValue: selectedFieldRawValue) ?? .weight
    }

    private var selectedFieldBinding: Binding<InventoryDetailField> {
        Binding(
            get: { selectedField },
            set: { selectedFieldRawValue = $0.rawValue }
        )
    }

    private var matchingItems: [InventoryItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var incompleteItems: [InventoryItem] {
        matchingItems.filter { !selectedField.isComplete($0.enrichmentInput) }
    }

    private var completedItems: [InventoryItem] {
        matchingItems.filter { selectedField.isComplete($0.enrichmentInput) }
    }

    private var totalCompletedCount: Int {
        items.lazy.filter { selectedField.isComplete($0.enrichmentInput) }.count
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Items to Enrich",
                    systemImage: "checklist",
                    description: Text("Add possessions to Inventory first.")
                )
            } else if matchingItems.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    if incompleteItems.isEmpty, searchText.isEmpty {
                        Section {
                            Label("Every item has been reviewed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    } else if !incompleteItems.isEmpty {
                        Section("Needs \(selectedField.title)") {
                            ForEach(incompleteItems) { item in
                                itemButton(item, isComplete: false)
                            }
                        }
                    }

                    if !completedItems.isEmpty {
                        Section("Reviewed") {
                            ForEach(completedItems) { item in
                                itemButton(item, isComplete: true)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Enrich Inventory")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search items")
        .safeAreaInset(edge: .top, spacing: 0) {
            enrichmentHeader
        }
        .sheet(item: $editorRequest) { request in
            if let item = items.first(where: { $0.id == request.itemID }) {
                InventoryDetailQuickEditor(item: item, field: request.field)
                    .enrichmentEditorPresentation(horizontalSizeClass: horizontalSizeClass)
            } else {
                ContentUnavailableView("Item Unavailable", systemImage: "shippingbox")
                    .presentationDetents([.medium])
            }
        }
#if DEBUG
        .task(id: items.count) {
            guard
                !didPresentDebugEditor,
                ProcessInfo.processInfo.arguments.contains("-ShowEnrichmentEditor"),
                let item = incompleteItems.first
            else { return }
            didPresentDebugEditor = true
            editorRequest = EditorRequest(itemID: item.id, field: selectedField)
        }
#endif
    }

    private var enrichmentHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Detail", selection: selectedFieldBinding) {
                ForEach(InventoryDetailField.allCases) { field in
                    Label(field.title, systemImage: field.symbol).tag(field)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 12) {
                ProgressView(value: Double(totalCompletedCount), total: Double(max(1, items.count)))
                Text("\(totalCompletedCount) of \(items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(totalCompletedCount) of \(items.count) items reviewed for \(selectedField.title.lowercased())")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func itemButton(_ item: InventoryItem, isComplete: Bool) -> some View {
        Button {
            editorRequest = EditorRequest(itemID: item.id, field: selectedField)
        } label: {
            EnrichmentItemRow(
                item: item,
                field: selectedField,
                categoryName: categories.first { $0.id == item.categoryID }?.name,
                isComplete: isComplete
            )
        }
        .buttonStyle(.plain)
    }
}

private extension InventoryEnrichmentView {
    struct EditorRequest: Identifiable {
        let itemID: UUID
        let field: InventoryDetailField
        var id: String { "\(itemID.uuidString)-\(field.rawValue)" }
    }
}

private struct EnrichmentItemRow: View {
    let item: InventoryItem
    let field: InventoryDetailField
    let categoryName: String?
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 12) {
            StoredImageView(data: item.thumbnailData ?? item.imageData, symbol: "shippingbox")
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(valueDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: isComplete ? "checkmark.circle.fill" : "chevron.right")
                .foregroundStyle(isComplete ? Color.green : Color.secondary)
                .font(isComplete ? .title3 : .caption.weight(.semibold))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the \(field.title.lowercased()) editor")
    }

    private var valueDescription: String {
        switch field {
        case .weight:
            guard let grams = item.weightGrams else { return "No weight entered" }
            return "\(grams.formatted(.number.precision(.fractionLength(0...1)))) g"
        case .category:
            return categoryName ?? "No category"
        case .quantity:
            return "Quantity: \(item.quantity.formatted())"
        case .status:
            return item.status.title
        case .notes:
            guard let notes = item.itemDescription, !notes.isEmpty else { return "No notes" }
            return notes
        }
    }
}

private struct InventoryDetailQuickEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Query(sort: \InventoryCategory.sortOrder) private var categories: [InventoryCategory]

    let field: InventoryDetailField
    @State private var currentItemID: UUID
    @State private var draft: Draft
    @State private var errorMessage: String?
    @FocusState private var focusedInput: FocusedInput?

    init(item: InventoryItem, field: InventoryDetailField) {
        self.field = field
        _currentItemID = State(initialValue: item.id)
        _draft = State(initialValue: Draft(item: item))
    }

    private var currentItem: InventoryItem? {
        items.first { $0.id == currentItemID }
    }

    private var nextIncompleteItem: InventoryItem? {
        guard let currentItem else { return nil }
        let candidates = items.filter {
            $0.id != currentItem.id && !field.isComplete($0.enrichmentInput)
        }
        return candidates.first {
            $0.name.localizedStandardCompare(currentItem.name) == .orderedDescending
        } ?? candidates.first
    }

    private var canSave: Bool {
        switch field {
        case .weight:
            return draft.weightGrams.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || parsedWeightGrams != nil
        case .category:
            return draft.categoryID != nil
        case .quantity, .status, .notes:
            return true
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let currentItem {
                    Form {
                        Section {
                            HStack(spacing: 12) {
                                StoredImageView(
                                    data: currentItem.thumbnailData ?? currentItem.imageData,
                                    symbol: "shippingbox"
                                )
                                .frame(width: 58, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(currentItem.name)
                                        .font(.headline)
                                    Text(field.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        inputSection

                        Section {
                            Button {
                                save(advance: true)
                            } label: {
                                Label(
                                    nextIncompleteItem == nil ? "Save & Finish" : "Save & Next",
                                    systemImage: "arrow.right.circle.fill"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canSave)

                            if nextIncompleteItem != nil {
                                Button("Skip", systemImage: "forward") {
                                    advanceWithoutSaving()
                                }
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                            }

                            Button("Save & Close") {
                                save(advance: false)
                            }
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .disabled(!canSave)
                        }
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ContentUnavailableView("Item Unavailable", systemImage: "shippingbox")
                }
            }
            .navigationTitle("Review \(field.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
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
            .onAppear(perform: focusPrimaryInput)
        }
    }

    @ViewBuilder
    private var inputSection: some View {
        switch field {
        case .weight:
            Section {
                LabeledContent("Weight") {
                    HStack(spacing: 6) {
                        TextField("0", text: $draft.weightGrams)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedInput, equals: .weight)
                            .frame(maxWidth: 130)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Leave this blank to confirm that no weight is available.")
            }
        case .category:
            Section {
                Picker("Category", selection: $draft.categoryID) {
                    Text("Choose a category").tag(nil as UUID?)
                    ForEach(categories) { category in
                        Text(category.name).tag(category.id as UUID?)
                    }
                }
            }
        case .quantity:
            Section {
                LabeledContent("Quantity") {
                    TextField("1", value: $draft.quantity, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedInput, equals: .quantity)
                        .frame(maxWidth: 100)
                }
                Stepper("Adjust quantity", value: $draft.quantity, in: 1...9_999)
                    .labelsHidden()
            }
        case .status:
            Section {
                Picker("Status", selection: $draft.status) {
                    ForEach(ItemStatus.allCases) { status in
                        Label(status.title, systemImage: status.symbol).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }
        case .notes:
            Section {
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(5...10)
                    .focused($focusedInput, equals: .notes)
            } footer: {
                Text("Leave this blank to confirm that no notes are needed.")
            }
        }
    }

    private var parsedWeightGrams: Double? {
        let normalized = draft.weightGrams
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, let grams = Double(normalized), grams >= 0 else { return nil }
        return grams
    }

    private func save(advance: Bool) {
        guard let currentItem else { return }

        switch field {
        case .weight:
            currentItem.weightGrams = draft.weightGrams.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : parsedWeightGrams
        case .category:
            currentItem.categoryID = draft.categoryID
        case .quantity:
            currentItem.quantity = max(1, draft.quantity)
        case .status:
            currentItem.status = draft.status
        case .notes:
            let notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            currentItem.itemDescription = notes.isEmpty ? nil : notes
        }
        currentItem.setDetail(field)
        currentItem.touch()

        do {
            _ = try InventoryHistoryRecorder.record(items: items, in: modelContext)
            try modelContext.save()
            if advance, let nextIncompleteItem {
                load(nextIncompleteItem)
            } else {
                dismiss()
            }
        } catch {
            modelContext.rollback()
            errorMessage = "The detail could not be saved. Your previous value was restored."
        }
    }

    private func advanceWithoutSaving() {
        guard let nextIncompleteItem else { return }
        load(nextIncompleteItem)
    }

    private func load(_ item: InventoryItem) {
        currentItemID = item.id
        draft = Draft(item: item)
        focusPrimaryInput()
    }

    private func focusPrimaryInput() {
        Task { @MainActor in
            await Task.yield()
            switch field {
            case .weight: focusedInput = .weight
            case .quantity: focusedInput = .quantity
            case .notes: focusedInput = .notes
            case .category, .status: focusedInput = nil
            }
        }
    }
}

private extension InventoryDetailQuickEditor {
    enum FocusedInput {
        case weight
        case quantity
        case notes
    }

    struct Draft {
        var weightGrams: String
        var categoryID: UUID?
        var quantity: Int
        var status: ItemStatus
        var notes: String

        init(item: InventoryItem) {
            if let grams = item.weightGrams {
                weightGrams = grams.formatted(.number.precision(.fractionLength(0...1)))
            } else {
                weightGrams = ""
            }
            categoryID = item.categoryID
            quantity = max(1, item.quantity)
            status = item.status
            notes = item.itemDescription ?? ""
        }
    }
}

private extension View {
    @ViewBuilder
    func enrichmentEditorPresentation(horizontalSizeClass: UserInterfaceSizeClass?) -> some View {
        if horizontalSizeClass == .compact {
            presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}
