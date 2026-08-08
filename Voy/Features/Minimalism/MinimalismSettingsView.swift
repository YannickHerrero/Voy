import SwiftData
import SwiftUI

struct MinimalismSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryCollection.name) private var collections: [InventoryCollection]

    let setting: MinimalismSettings?
    @State private var nomadicCollectionID: UUID?
    @State private var goalText: String
    @State private var errorMessage: String?

    init(setting: MinimalismSettings?) {
        self.setting = setting
        _nomadicCollectionID = State(initialValue: setting?.nomadicCollectionID)
        _goalText = State(initialValue: setting?.possessionGoal.map(String.init) ?? "")
    }

    private var parsedGoal: Int? {
        guard !goalText.isEmpty else { return nil }
        guard let goal = Int(goalText), goal > 0 else { return nil }
        return goal
    }

    private var canSave: Bool {
        goalText.isEmpty || parsedGoal != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Nomadic collection", selection: $nomadicCollectionID) {
                        Text("Not set").tag(nil as UUID?)
                        ForEach(collections) { collection in
                            Text(collection.name).tag(collection.id as UUID?)
                        }
                    }
                } header: {
                    Text("Nomadic Inventory")
                } footer: {
                    Text("Owned items outside this collection are counted as possessions to remove.")
                }

                Section {
                    HStack {
                        Text("At most")
                        TextField("No goal", text: $goalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("items")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Possession Goal")
                } footer: {
                    Text("Leave this blank if you do not want a goal.")
                }
            }
            .navigationTitle("Minimalism Settings")
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
            .alert("Couldn’t Save Settings", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private func save() {
        let target = setting ?? MinimalismSettings()
        target.nomadicCollectionID = nomadicCollectionID
        target.possessionGoal = parsedGoal
        target.modifiedAt = Date()
        if setting == nil {
            modelContext.insert(target)
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "Your settings could not be saved. Check your connection and try again."
        }
    }
}
