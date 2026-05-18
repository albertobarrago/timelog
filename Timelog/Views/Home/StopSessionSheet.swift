import TimelogCore
import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct StopSessionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: ActiveSession

    @State private var hours: Int
    @State private var minutes: Int
    @State private var notes: String

    init(session: ActiveSession) {
        self.session = session
        let elapsed = max(0, Int(Date().timeIntervalSince(session.startDate) / 60))
        _hours = State(initialValue: elapsed / 60)
        _minutes = State(initialValue: elapsed % 60)
        _notes = State(initialValue: session.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Session")) {
                    if let client = session.client {
                        LabeledContent(String(localized: "Client"), value: client.name)
                    }
                    if let project = session.project {
                        LabeledContent(String(localized: "Project"), value: project.name)
                    }
                    LabeledContent(String(localized: "Started")) {
                        Text(session.startDate, style: .time)
                    }
                }

                Section(String(localized: "Duration")) {
                    Stepper("\(hours)h", value: $hours, in: 0...23)
                    Stepper("\(minutes)m", value: $minutes, in: 0...59)
                }

                Section(String(localized: "Notes")) {
                    TextField(String(localized: "Optional"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: "Stop Tracking"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Log")) { stop() }
                        .disabled(hours == 0 && minutes == 0)
                }
            }
        }
    }

    private func stop() {
        let entry = session.asTimeEntry(
            durationMinutes: hours * 60 + minutes,
            notes: notes.isEmpty ? nil : notes
        )
        context.insert(entry)
        NotificationManager.shared.cancelSession(id: session.notificationID)
        context.delete(session)
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        dismiss()
    }
}
