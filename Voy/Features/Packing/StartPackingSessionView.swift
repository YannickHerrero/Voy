import SwiftData
import SwiftUI

struct StartPackingSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingTemplate.modifiedAt, order: .reverse) private var templates: [PackingTemplate]
    @Query private var templateEntries: [PackingTemplateEntry]
    @Query private var items: [InventoryItem]

    @State private var selectedTemplateID: UUID?
    @State private var sessionName: String
    @State private var startDate = Date()
    @State private var errorMessage: String?

    init(template: PackingTemplate? = nil) {
        _selectedTemplateID = State(initialValue: template?.id)
        let defaultName = template.map { "\($0.name) — \(Date().formatted(.dateTime.month(.wide).year()))" } ?? ""
        _sessionName = State(initialValue: defaultName)
    }

    private var selectedTemplate: PackingTemplate? {
        templates.first { $0.id == selectedTemplateID }
    }

    private var selectedEntryCount: Int {
        guard let selectedTemplateID else { return 0 }
        return templateEntries.lazy.filter { $0.templateID == selectedTemplateID }.reduce(0) { $0 + $1.quantity }
    }

    private var canStart: Bool {
        selectedTemplate != nil
            && selectedEntryCount > 0
            && !sessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Template", selection: $selectedTemplateID) {
                        Text("Choose a template").tag(nil as UUID?)
                        ForEach(templates) { template in
                            Text(template.name).tag(template.id as UUID?)
                        }
                    }
                    .onChange(of: selectedTemplateID) { oldValue, newValue in
                        if sessionName.isEmpty || sessionName == defaultName(for: oldValue) {
                            sessionName = defaultName(for: newValue)
                        }
                    }

                    TextField("Trip name", text: $sessionName)
                        .textInputAutocapitalization(.words)
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                }

                if let selectedTemplate {
                    Section("Summary") {
                        LabeledContent("Template", value: selectedTemplate.name)
                        LabeledContent("Items", value: selectedEntryCount.formatted())
                    }
                }

                if selectedTemplate != nil, selectedEntryCount == 0 {
                    Section {
                        Label("Add items to this template before starting a session.", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Start Packing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: startSession)
                        .fontWeight(.semibold)
                        .disabled(!canStart)
                }
            }
            .onAppear {
                if selectedTemplateID == nil {
                    selectedTemplateID = templates.first?.id
                    if sessionName.isEmpty {
                        sessionName = defaultName(for: selectedTemplateID)
                    }
                }
            }
            .alert("Couldn’t Start Session", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private func defaultName(for templateID: UUID?) -> String {
        guard let template = templates.first(where: { $0.id == templateID }) else { return "" }
        return "\(template.name) — \(startDate.formatted(.dateTime.month(.wide).year()))"
    }

    private func startSession() {
        guard let template = selectedTemplate else { return }
        let name = sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = PackingSessionFactory.create(
            from: template,
            name: name,
            startDate: startDate,
            templateEntries: templateEntries,
            items: items,
            in: modelContext
        )
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "The trip could not be saved. Check your connection and try again."
        }
    }
}
