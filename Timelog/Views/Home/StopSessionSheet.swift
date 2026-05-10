import SwiftUI
import SwiftData

struct StopSessionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: ActiveSession

    @State private var hours: Int
    @State private var minutes: Int
    @State private var notes: String

    init(session: ActiveSession) {
        self.session = session
        let elapsed = max(1, Int(Date().timeIntervalSince(session.startDate) / 60))
        _hours = State(initialValue: elapsed / 60)
        _minutes = State(initialValue: elapsed % 60)
        _notes = State(initialValue: session.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let client = session.client {
                        LabeledContent("Client", value: client.name)
                    }
                    if let project = session.project {
                        LabeledContent("Project", value: project.name)
                    }
                    LabeledContent("Started") {
                        Text(session.startDate, style: .time)
                    }
                }

                Section("Duration") {
                    HStack(spacing: 16) {
                        Picker("Hours", selection: $hours) {
                            ForEach(0..<24, id: \.self) { Text("\($0)h").tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)

                        Picker("Min", selection: $minutes) {
                            ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) {
                                Text("\($0)m").tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Stop Tracking")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { stop() }
                        .disabled(hours == 0 && minutes == 0)
                }
            }
        }
    }

    private func stop() {
        let entry = TimeEntry(
            date: session.startDate,
            durationMinutes: hours * 60 + minutes,
            notes: notes.isEmpty ? nil : notes,
            client: session.client,
            project: session.project
        )
        context.insert(entry)
        NotificationManager.shared.cancelSession(id: session.notificationID)
        context.delete(session)
        dismiss()
    }
}
