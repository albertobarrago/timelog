import SwiftData
import SwiftUI
import TimelogCore

struct HistoryMacView: View {
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<TimeEntry> { $0.deletedAt == nil }, sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]

    @State private var selectedDate = Date()
    @State private var entryToEdit: TimeEntry?

    // MARK: - Computed

    private var entries: [TimeEntry] {
        allEntries.filter { $0.userId == settings.userId && Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var totalMinutes: Int {
        entries.reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Weekly chart

    private var weekDays: [Date] {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))
        else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func minutesForDay(_ date: Date) -> Int {
        allEntries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private var maxWeekMinutes: Int {
        weekDays.map { minutesForDay($0) }.max() ?? 0
    }

    // MARK: - Grouped entries

    private struct ClientGroup: Identifiable {
        let id: String
        let clientName: String
        let color: Color
        var entries: [TimeEntry]
        var total: Int { entries.reduce(0) { $0 + $1.durationMinutes } }
    }

    private var groupedEntries: [ClientGroup] {
        var dict: [String: ClientGroup] = [:]
        for entry in entries {
            let key   = entry.client?.name ?? ""
            let name  = entry.client?.name ?? "No client"
            let color = entry.client?.color ?? Color.secondary.opacity(0.5)
            if dict[key] == nil {
                dict[key] = ClientGroup(id: key, clientName: name, color: color, entries: [])
            }
            dict[key]!.entries.append(entry)
        }
        return dict.values.sorted { $0.total > $1.total }
    }

    // MARK: - Body

    var body: some View {
        List {
            // Header: date nav + total
            Section {
                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 8) {
                        DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.stepperField)
                        Button("Today") { selectedDate = Date() }
                            .disabled(Calendar.current.isDateInToday(selectedDate))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }

                    Spacer()

                    if totalMinutes > 0 {
                        Text(totalMinutes.formattedDuration)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 4)

                WeeklyBarChart(
                    weekDays: weekDays,
                    selectedDate: selectedDate,
                    minutesForDay: minutesForDay,
                    maxMinutes: maxWeekMinutes
                ) { selectedDate = $0 }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // Entries grouped by client
            if entries.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("No entries")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Pick another day to review logged time.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 32)
                        Spacer()
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(groupedEntries) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            HistoryMacRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture { entryToEdit = entry }
                                .contextMenu {
                                    Button("Edit") { entryToEdit = entry }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        entry.deletedAt = .now
                                    }
                                }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(group.color)
                                .frame(width: 8, height: 8)
                            Text(group.clientName)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(group.total.formattedDuration)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("History")
        .sheet(item: $entryToEdit) { QuickLogMacView(entry: $0) }
    }

}

// MARK: - Weekly Bar Chart

private struct WeeklyBarChart: View {
    let weekDays: [Date]
    let selectedDate: Date
    let minutesForDay: (Date) -> Int
    let maxMinutes: Int
    let onSelect: (Date) -> Void

    private let maxBarHeight: CGFloat = 36

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(weekDays, id: \.self) { date in
                DayBar(
                    date: date,
                    minutes: minutesForDay(date),
                    maxMinutes: maxMinutes,
                    maxBarHeight: maxBarHeight,
                    isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                    isFuture: date > Calendar.current.startOfDay(for: Date()),
                    onSelect: onSelect
                )
            }
        }
        .frame(height: maxBarHeight + 28)
    }
}

private struct DayBar: View {
    let date: Date
    let minutes: Int
    let maxMinutes: Int
    let maxBarHeight: CGFloat
    let isSelected: Bool
    let isFuture: Bool
    let onSelect: (Date) -> Void

    private var barHeight: CGFloat {
        guard maxMinutes > 0, minutes > 0 else { return 3 }
        return max(4, CGFloat(minutes) / CGFloat(maxMinutes) * maxBarHeight)
    }

    private var barColor: Color {
        if isSelected  { return .accentColor }
        if isFuture    { return Color.secondary.opacity(0.1) }
        if minutes > 0 { return Color.accentColor.opacity(0.28) }
        return Color.secondary.opacity(0.13)
    }

    var body: some View {
        Button { if !isFuture { onSelect(date) } } label: {
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(height: barHeight)
                    .animation(.easeOut(duration: 0.15), value: barHeight)
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(
                        isSelected ? Color.accentColor
                        : isFuture  ? Color.secondary.opacity(0.35)
                        : .secondary
                    )
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }
}

// MARK: - Row

private struct HistoryMacRow: View {
    let entry: TimeEntry

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(entry.client?.color ?? Color.secondary.opacity(0.3))
                .frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                if let project = entry.project {
                    Text(project.name).fontWeight(.medium)
                } else if let notes = entry.notes, !notes.isEmpty {
                    Text(notes).fontWeight(.medium).lineLimit(1)
                } else {
                    Text(entry.client?.name ?? "No client").fontWeight(.medium)
                }
                if entry.project != nil, let notes = entry.notes, !notes.isEmpty {
                    Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(entry.durationMinutes.formattedDuration)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
