import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct InventoryItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryCategory.sortOrder) private var categories: [InventoryCategory]
    @Query(sort: \InventoryCollection.name) private var collections: [InventoryCollection]

    let item: InventoryItem?
    @State private var draft: Draft
    @State private var showsMoreDetails: Bool
    @State private var errorMessage: String?
    @State private var showsPhotoOptions = false
    @State private var showsCamera = false
    @State private var showsPhotoLibrary = false
    @State private var showsOnlineBrowser = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingPhoto: PhotoProcessingResult?
    @State private var pendingSourceURL: URL?
    @State private var pendingImageURL: URL?
    @State private var isPreparingImage = false
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
        !isPreparingImage
            && !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.categoryID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showsPhotoOptions = true
                    } label: {
                        ZStack(alignment: .bottom) {
                            StoredImageView(data: draft.imageData ?? draft.thumbnailData, symbol: "camera")
                                .aspectRatio(1, contentMode: .fit)

                            if isPreparingImage {
                                ProgressView("Removing background…")
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                                    .background(.regularMaterial)
                            } else {
                                Label(draft.imageData == nil ? "Add Photo" : "Change Photo", systemImage: "camera")
                                    .font(.subheadline.weight(.medium))
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                                    .background(.regularMaterial)
                            }
                        }
                        .frame(maxWidth: 360)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isPreparingImage)
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
            .confirmationDialog("Add a Photo", isPresented: $showsPhotoOptions, titleVisibility: .visible) {
                Button("Take Photo", systemImage: "camera") {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showsCamera = true
                    } else {
                        errorMessage = "A camera is not available on this device."
                    }
                }
                Button("Choose from Photo Library", systemImage: "photo.on.rectangle") {
                    showsPhotoLibrary = true
                }
                Button("Find Online", systemImage: "safari") {
                    showsOnlineBrowser = true
                }
                if draft.imageData != nil {
                    Button("Remove Photo", systemImage: "trash", role: .destructive) {
                        removePhoto()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(
                isPresented: $showsPhotoLibrary,
                selection: $selectedPhotoItem,
                matching: .images,
                preferredItemEncoding: .current
            )
            .sheet(isPresented: $showsCamera) {
                CameraPicker { image in
                    showsCamera = false
                    prepareCameraImage(image)
                } onCancel: {
                    showsCamera = false
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showsOnlineBrowser) {
                OnlineImageBrowserView { selection in
                    showsOnlineBrowser = false
                    prepareOnlineImage(selection)
                }
            }
            .sheet(item: $pendingPhoto, onDismiss: clearPendingSource) { result in
                PhotoNormalizationPreview(result: result) { image in
                    apply(image)
                    draft.sourceURL = pendingSourceURL
                    draft.originalImageURL = pendingImageURL
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                prepareLibraryPhoto(newItem)
            }
            .alert("Something Went Wrong", isPresented: Binding(
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

    private func prepareLibraryPhoto(_ item: PhotosPickerItem) {
        clearPendingSource()
        isPreparingImage = true
        Task {
            defer {
                isPreparingImage = false
                selectedPhotoItem = nil
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw ImageFileProcessor.ProcessingError.unreadableImage
                }
                pendingPhoto = try await PhotoNormalizer.process(data)
            } catch {
                errorMessage = "That photo could not be opened. Try choosing another image."
            }
        }
    }

    private func prepareCameraImage(_ image: UIImage) {
        clearPendingSource()
        guard let data = image.jpegData(compressionQuality: 0.95) else {
            errorMessage = "That photo could not be read. Please take it again."
            return
        }
        isPreparingImage = true
        Task {
            defer { isPreparingImage = false }
            do {
                pendingPhoto = try await PhotoNormalizer.process(data)
            } catch {
                errorMessage = "That photo could not be prepared. Please take it again."
            }
        }
    }

    private func prepareOnlineImage(_ selection: OnlineImageSelection) {
        pendingSourceURL = selection.pageURL
        pendingImageURL = selection.imageURL
        isPreparingImage = true
        Task {
            defer { isPreparingImage = false }
            do {
                pendingPhoto = try await PhotoNormalizer.process(selection.data)
            } catch {
                clearPendingSource()
                errorMessage = "That online image could not be prepared. Try choosing another one."
            }
        }
    }

    private func apply(_ image: PreparedImage) {
        draft.imageData = image.displayData
        draft.thumbnailData = image.thumbnailData
        draft.originalImageData = image.originalData
    }

    private func removePhoto() {
        draft.imageData = nil
        draft.thumbnailData = nil
        draft.originalImageData = nil
        draft.sourceURL = nil
        draft.originalImageURL = nil
    }

    private func clearPendingSource() {
        pendingSourceURL = nil
        pendingImageURL = nil
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
        target.sourceURL = draft.sourceURL
        target.originalImageURL = draft.originalImageURL
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
        var sourceURL: URL?
        var originalImageURL: URL?

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
            sourceURL = item?.sourceURL
            originalImageURL = item?.originalImageURL
        }

        var hasOptionalDetails: Bool {
            status != .owned || quantity != 1 || !weightKilograms.isEmpty
                || !itemDescription.isEmpty || !collectionIDs.isEmpty
        }
    }
}
