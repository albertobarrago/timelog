import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync

struct MacSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(TimerViewModel.self) private var timerVM
    @Environment(\.openURL) private var openURL
    @Query(sort: \TimeEntry.date, order: .reverse) private var entries: [TimeEntry]
    var body: some View {
        @Bindable var store = store
        Form {
            Section("Pomodoro") {
                Stepper("Focus: \(store.pomodoroWork) min",
                        value: $store.pomodoroWork, in: 1...90)
                    .onChange(of: store.pomodoroWork) { timerVM.applySettings(store) }
                Stepper("Short break: \(store.pomodoroShortBreak) min",
                        value: $store.pomodoroShortBreak, in: 1...30)
                    .onChange(of: store.pomodoroShortBreak) { timerVM.applySettings(store) }
                Stepper("Long break: \(store.pomodoroLongBreak) min",
                        value: $store.pomodoroLongBreak, in: 1...60)
                    .onChange(of: store.pomodoroLongBreak) { timerVM.applySettings(store) }
            }

            Section {
                Toggle("Daily reminder", isOn: $store.reminderEnabled)
                if store.reminderEnabled {
                    DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Days").font(.caption).foregroundStyle(.secondary)
                        DayPickerMac(selectedDays: $store.reminderDays)
                    }
                }
            } header: {
                Text("Reminders")
            }

            Section {
                DatePicker("Notify if still open at",
                           selection: trackingEndTime,
                           displayedComponents: .hourAndMinute)
            } header: {
                Text("Smart Tracking")
            } footer: {
                Text("Sends a notification if a session is still running at this time.")
            }

            Section {
                HStack {
                    Button("Sync Now") {
                        MongoSyncService.shared.triggerSync()
                    }
                    .disabled(MongoSyncService.shared.readConnectionString() == nil)
                    Spacer()
                    MongoSyncStatusRowMac()
                }
            } header: {
                Text("MongoDB Sync")
            } footer: {
                Text("Connection string is loaded automatically from ~/.config/timelog/mongo.local on first launch.")
            }

            Section("Export") {
                Button("Export this week via Email") { exportEmail() }
            }

            Section("About") {
                LabeledContent("Developer") {
                    Link("Alberto Barrago", destination: URL(string: "https://github.com/AlbertoBarrago")!)
                }
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(maxWidth: 520)
    }

    // MARK: - Actions

    private func exportEmail() {
        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEntries = entries.filter { $0.date >= weekStart }

        var lines = ["Timelog — Week of \(weekStart.formatted(date: .abbreviated, time: .omitted))", ""]
        for entry in weekEntries.sorted(by: { $0.date < $1.date }) {
            let dateStr = entry.date.formatted(date: .abbreviated, time: .omitted)
            let dur = entry.durationMinutes.formattedDuration
            let client = entry.client?.name ?? "—"
            let project = entry.project?.name ?? "—"
            let notes = entry.notes.map { " — \($0)" } ?? ""
            lines.append("[\(dateStr)] \(client) / \(project): \(dur)\(notes)")
        }
        let total = weekEntries.reduce(0) { $0 + $1.durationMinutes }
        lines += ["", "Total: \(total.formattedDuration)"]

        let body = lines.joined(separator: "\n")
        let subject = "Timelog Week Export"
        let mailto = "mailto:?subject=\(subject.urlEncoded)&body=\(body.urlEncoded)"
        if let url = URL(string: mailto) { openURL(url) }
    }

    // MARK: - Bindings

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
                c.hour = store.reminderHour; c.minute = store.reminderMinute
                return Calendar.current.date(from: c) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.reminderHour = c.hour ?? 17
                store.reminderMinute = c.minute ?? 0
            }
        )
    }

    private var trackingEndTime: Binding<Date> {
        Binding(
            get: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
                c.hour = store.trackingEndHour; c.minute = store.trackingEndMinute
                return Calendar.current.date(from: c) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.trackingEndHour = c.hour ?? 18
                store.trackingEndMinute = c.minute ?? 0
            }
        )
    }
}

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

private struct MongoSyncStatusRowMac: View {
    private var mongo: MongoSyncService { MongoSyncService.shared }

    var body: some View {
        if mongo.isSyncing {
            Label("Syncing…", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption).foregroundStyle(.secondary)
        } else if let error = mongo.lastError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.red)
        } else if let date = mongo.lastSyncDate {
            Label("Last sync: \(date.formatted(date: .omitted, time: .shortened))",
                  systemImage: "checkmark.circle")
                .font(.caption).foregroundStyle(.green)
        }
    }
}

private struct DayPickerMac: View {
    @Binding var selectedDays: Set<Int>

    private let days: [(label: String, index: Int)] = [
        ("M", 2), ("Tu", 3), ("W", 4), ("Th", 5), ("F", 6), ("Sa", 7), ("Su", 1)
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.index) { day in
                let on = selectedDays.contains(day.index)
                Button {
                    if on { selectedDays.remove(day.index) }
                    else  { selectedDays.insert(day.index) }
                } label: {
                    Text(day.label)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(on ? Color.accentColor : Color.secondary.opacity(0.15),
                                    in: Circle())
                        .foregroundStyle(on ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
