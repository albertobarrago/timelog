import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Query(sort: \TimeEntry.date, order: .reverse) private var entries: [TimeEntry]
    @Environment(SettingsStore.self) private var store
    @State private var apiKey = ""

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("Wethod API") {
                    TextField("Base URL", text: $store.wethodBaseURL)
                        .onChange(of: store.wethodBaseURL) { store.save() }
                    SecureField("API Key", text: $apiKey)
                        .onSubmit { store.wethodAPIKey = apiKey }
                        .onChange(of: apiKey) { store.wethodAPIKey = apiKey }
                }

                Section("Pomodoro") {
                    Stepper("Focus: \(store.pomodoroWork) min",
                            value: $store.pomodoroWork, in: 1...90)
                        .onChange(of: store.pomodoroWork) { store.save() }
                    Stepper("Short break: \(store.pomodoroShortBreak) min",
                            value: $store.pomodoroShortBreak, in: 1...30)
                        .onChange(of: store.pomodoroShortBreak) { store.save() }
                    Stepper("Long break: \(store.pomodoroLongBreak) min",
                            value: $store.pomodoroLongBreak, in: 1...60)
                        .onChange(of: store.pomodoroLongBreak) { store.save() }
                }

                Section("Export") {
                    Button("Export this week via Email") { exportEmail() }
                }

                Section("Danger Zone") {
                    Button("Delete all entries", role: .destructive) {
                        for e in entries { context.delete(e) }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .onAppear { apiKey = store.wethodAPIKey }
        }
    }

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
        if let url = URL(string: mailto) {
            openURL(url)
        }
    }
}

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
