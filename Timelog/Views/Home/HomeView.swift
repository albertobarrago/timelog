import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]
    @State private var showingQuickLog = false
    @State private var entryToEdit: TimeEntry?

    private var todayEntries: [TimeEntry] {
        let cal = Calendar.current
        return allEntries.filter { cal.isDateInToday($0.date) }
    }

    private var totalMinutes: Int { todayEntries.reduce(0) { $0 + $1.durationMinutes } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Today total card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(totalMinutes.formattedDuration)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Image(systemName: "clock.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary.opacity(0.4))
                }
                .padding()
                .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
                .padding()

                if todayEntries.isEmpty {
                    ContentUnavailableView(
                        "No entries today",
                        systemImage: "clock",
                        description: Text("Tap + to log your first entry")
                    )
                } else {
                    List {
                        ForEach(todayEntries) { entry in
                            EntryRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture { entryToEdit = entry }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        context.delete(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("Timelog")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingQuickLog = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingQuickLog) { QuickLogSheet() }
            .sheet(item: $entryToEdit) { QuickLogSheet(entry: $0) }
        }
    }
}

private struct EntryRow: View {
    let entry: TimeEntry

    var body: some View {
        HStack(spacing: 12) {
            if let color = entry.client?.color {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 4, height: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.client?.name ?? "No client")
                    .font(.subheadline.weight(.semibold))
                if let proj = entry.project {
                    Text(proj.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(entry.durationMinutes.formattedDuration)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
