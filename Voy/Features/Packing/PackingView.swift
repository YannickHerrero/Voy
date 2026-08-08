import SwiftData
import SwiftUI

struct PackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingTemplate.modifiedAt, order: .reverse) private var templates: [PackingTemplate]
    @Query(sort: \PackingSession.startDate, order: .reverse) private var sessions: [PackingSession]
    @Query private var templateEntries: [PackingTemplateEntry]
    @Query private var sessionEntries: [PackingSessionEntry]
    @Query private var items: [InventoryItem]

    @State private var showsNewTemplate = false
    @State private var showsStartSession = false
    @State private var newTemplateName = ""
    @State private var errorMessage: String?

    private var activeSessions: [PackingSession] {
        sessions.filter { $0.state == .active }
    }

    private var historicalSessions: [PackingSession] {
        sessions.filter { $0.state != .active }
    }

    var body: some View {
        Group {
            if templates.isEmpty && sessions.isEmpty {
                ContentUnavailableView {
                    Label("Pack once, reuse often", systemImage: "suitcase")
                } description: {
                    Text("Create a template from possessions already in Inventory.")
                } actions: {
                    Button("New Template") { showsNewTemplate = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    if !activeSessions.isEmpty {
                        Section("Active Sessions") {
                            ForEach(activeSessions) { session in
                                NavigationLink {
                                    PackingSessionDetailView(session: session)
                                } label: {
                                    sessionRow(session)
                                }
                            }
                        }
                    }

                    Section("Templates") {
                        if templates.isEmpty {
                            Button("New Packing Template", systemImage: "plus") {
                                showsNewTemplate = true
                            }
                        } else {
                            ForEach(templates) { template in
                                NavigationLink {
                                    PackingTemplateDetailView(template: template)
                                } label: {
                                    templateRow(template)
                                }
                            }
                        }
                    }

                    if !historicalSessions.isEmpty {
                        Section("Past Sessions") {
                            ForEach(historicalSessions) { session in
                                NavigationLink {
                                    PackingSessionDetailView(session: session)
                                } label: {
                                    sessionRow(session)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Packing")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Start Packing Session", systemImage: "checklist") {
                        showsStartSession = true
                    }
                    .disabled(templates.isEmpty)

                    Button("New Template", systemImage: "plus") {
                        showsNewTemplate = true
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showsStartSession) {
            StartPackingSessionView()
        }
        .alert("New Packing Template", isPresented: $showsNewTemplate) {
            TextField("Template name", text: $newTemplateName)
            Button("Cancel", role: .cancel) { newTemplateName = "" }
            Button("Create", action: createTemplate)
                .disabled(newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("For example, One Week Travel or Marathon Weekend.")
        }
        .alert("Couldn’t Create Template", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private func sessionRow(_ session: PackingSession) -> some View {
        let progress = PackingCalculations.progress(
            for: sessionEntries.filter { $0.sessionID == session.id }.map(\.metricInput)
        )

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.name)
                    .font(.body.weight(.medium))
                Spacer()
                if session.state != .active {
                    Text(session.state.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                Text("\(progress.packedUnits) / \(progress.totalUnits) packed")
                if progress.knownTotalWeightGrams > 0 {
                    Text("\(WeightFormatting.string(grams: progress.packedWeightGrams)) / \(WeightFormatting.string(grams: progress.knownTotalWeightGrams))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            ProgressView(value: progress.fractionComplete)
                .tint(progress.fractionComplete == 1 ? .green : .accentColor)
        }
        .padding(.vertical, 4)
    }

    private func templateRow(_ template: PackingTemplate) -> some View {
        let entries = templateEntries.filter { $0.templateID == template.id }
        let inputs = entries.compactMap { entry -> PackingMetricInput? in
            guard let item = items.first(where: { $0.id == entry.itemID }) else { return nil }
            return PackingMetricInput(
                quantity: entry.quantity,
                weightGramsPerUnit: item.weightGrams,
                isPacked: false
            )
        }
        let progress = PackingCalculations.progress(for: inputs)

        return VStack(alignment: .leading, spacing: 5) {
            Text(template.name)
                .font(.body.weight(.medium))
            HStack(spacing: 12) {
                Text("\(progress.totalUnits) \(progress.totalUnits == 1 ? "item" : "items")")
                if progress.knownTotalWeightGrams > 0 {
                    Text(WeightFormatting.string(grams: progress.knownTotalWeightGrams))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private func createTemplate() {
        let name = newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !templates.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
            newTemplateName = ""
            errorMessage = "A template with that name already exists."
            return
        }

        modelContext.insert(PackingTemplate(name: name))
        do {
            try modelContext.save()
            newTemplateName = ""
        } catch {
            modelContext.rollback()
            errorMessage = "The template could not be saved. Check your connection and try again."
        }
    }
}
