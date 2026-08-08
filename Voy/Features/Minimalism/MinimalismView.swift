import Charts
import SwiftData
import SwiftUI

struct MinimalismView: View {
    @Query private var items: [InventoryItem]
    @Query(sort: \InventoryCategory.sortOrder) private var categories: [InventoryCategory]
    @Query(sort: \InventoryCollection.name) private var collections: [InventoryCollection]
    @Query(sort: \MinimalismSettings.modifiedAt, order: .reverse) private var settings: [MinimalismSettings]
    @Query(sort: \InventorySnapshot.capturedAt) private var snapshots: [InventorySnapshot]

    @State private var showsSettings = false

    private var setting: MinimalismSettings? { settings.first }

    private var metrics: InventoryMetrics {
        InventoryCalculations.metrics(
            for: items.map(\.summaryInput),
            nomadicCollectionID: setting?.nomadicCollectionID
        )
    }

    private var nomadicCollection: InventoryCollection? {
        collections.first { $0.id == setting?.nomadicCollectionID }
    }

    private var dailySnapshots: [InventorySnapshot] {
        let calendar = Calendar.current
        var latestByDay: [Date: InventorySnapshot] = [:]
        for snapshot in snapshots {
            let day = calendar.startOfDay(for: snapshot.capturedAt)
            if latestByDay[day]?.capturedAt ?? .distantPast < snapshot.capturedAt {
                latestByDay[day] = snapshot
            }
        }
        return latestByDay.values.sorted { $0.capturedAt < $1.capturedAt }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 34) {
                overview
                Divider()
                nomadicOverview

                if let goal = setting?.possessionGoal {
                    Divider()
                    goalSection(goal)
                }

                if !categoryRows.isEmpty {
                    Divider()
                    categoryBreakdown
                }

                if dailySnapshots.count > 1 {
                    Divider()
                    historyChart
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Minimalism")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsSettings = true
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showsSettings) {
            MinimalismSettingsView(setting: setting)
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text(metrics.ownedCount.formatted())
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                Text("possessions currently owned")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if let changeDescription {
                    Text(changeDescription)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }

            Grid(horizontalSpacing: 28, verticalSpacing: 6) {
                GridRow {
                    statusMetric(metrics.ownedCount, title: "Owned")
                    statusMetric(metrics.outgoingCount, title: "Outgoing")
                    statusMetric(metrics.archivedCount, title: "Archived")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }

    private var nomadicOverview: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Nomadic Inventory", subtitle: "What remains when home becomes wherever you are.")

            if let nomadicCollection {
                VStack(spacing: 0) {
                    subsetLink(
                        title: "Current life",
                        count: metrics.ownedCount,
                        filter: InventoryFilter(status: .owned)
                    )
                    Divider()
                    subsetLink(
                        title: "Nomadic life",
                        count: metrics.nomadicCount,
                        filter: InventoryFilter(collectionID: nomadicCollection.id, status: .owned)
                    )
                    Divider()
                    subsetLink(
                        title: "To remove",
                        count: metrics.toRemoveCount,
                        filter: InventoryFilter(status: .owned, excludesCollectionID: nomadicCollection.id)
                    )
                }

                Text("Using the \(nomadicCollection.name) collection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ContentUnavailableView {
                    Label("Choose a Nomadic Collection", systemImage: "backpack")
                } description: {
                    Text("Designate the collection that represents the possessions you want to keep long term.")
                } actions: {
                    Button("Choose Collection") { showsSettings = true }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func goalSection(_ goal: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Goal", subtitle: "At most \(goal) possessions")
            ProgressView(value: goalProgress(goal))
            if metrics.ownedCount <= goal {
                Text("Your current inventory is within this goal.")
                    .foregroundStyle(.secondary)
            } else {
                Text("\((metrics.ownedCount - goal).formatted()) possessions to review")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("By Category", subtitle: "Currently owned possessions")

            VStack(spacing: 0) {
                ForEach(categoryRows.indices, id: \.self) { index in
                    let row = categoryRows[index]
                    NavigationLink {
                        InventorySubsetView(
                            title: row.category.name,
                            baseFilter: InventoryFilter(categoryID: row.category.id, status: .owned)
                        )
                    } label: {
                        HStack {
                            Text(row.category.name)
                            Spacer()
                            Text(row.count.formatted())
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < categoryRows.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var historyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("History", subtitle: "Owned possessions over time")
            Chart(dailySnapshots) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.capturedAt),
                    y: .value("Possessions", snapshot.ownedCount)
                )
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value("Date", snapshot.capturedAt),
                    y: .value("Possessions", snapshot.ownedCount)
                )
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 190)
            .accessibilityLabel("Inventory history chart")
        }
    }

    private func subsetLink(title: String, count: Int, filter: InventoryFilter) -> some View {
        NavigationLink {
            InventorySubsetView(title: title, baseFilter: filter)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(count.formatted())
                    .font(.title3.weight(.semibold).monospacedDigit())
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusMetric(_ count: Int, title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(count.formatted())
                .font(.title2.weight(.semibold).monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var categoryRows: [(category: InventoryCategory, count: Int)] {
        categories.compactMap { category in
            guard let count = metrics.categoryCounts[category.id], count > 0 else { return nil }
            return (category, count)
        }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count { return lhs.category.name < rhs.category.name }
            return lhs.count > rhs.count
        }
    }

    private var changeDescription: String? {
        guard
            let year = Calendar.current.dateInterval(of: .year, for: Date()),
            let reference = dailySnapshots.first(where: { $0.capturedAt >= year.start }),
            reference.capturedAt < Calendar.current.startOfDay(for: Date())
        else { return nil }
        let change = metrics.ownedCount - reference.ownedCount
        guard change != 0 else { return nil }
        let arrow = change < 0 ? "↓" : "↑"
        return "\(arrow) \(abs(change).formatted()) since \(reference.capturedAt.formatted(.dateTime.month(.wide)))"
    }

    private func goalProgress(_ goal: Int) -> Double {
        guard metrics.ownedCount > goal, metrics.ownedCount > 0 else { return 1 }
        return Double(goal) / Double(metrics.ownedCount)
    }
}
