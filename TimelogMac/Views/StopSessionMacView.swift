import SwiftUI
import SwiftData
import TimelogCore

struct StopSessionMacView: View {
    var onDismiss: (() -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: ActiveSession

    @State private var hours: Int
    @State private var minutes: Int
    @State private var notes: String
    @State private var showDiscardAlert = false

    init(session: ActiveSession, onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        self.session = session
        let elapsed = max(0, Int(Date().timeIntervalSince(session.startDate) / 60))
        _hours = State(initialValue: elapsed / 60)
        _minutes = State(initialValue: elapsed % 60)
        _notes = State(initialValue: session.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stop Tracking")
                .font(.headline)

            if let client = session.client {
                LabeledContent("Client", value: client.name)
            }
            if let project = session.project {
                LabeledContent("Project", value: project.name)
            }
            LabeledContent("Started") {
                Text(session.startDate, style: .time)
            }

            Divider()

            DurationPickerMac(hours: $hours, minutes: $minutes)

            TextField("Notes (optional)", text: $notes)

            HStack {
                Button("Discard", role: .destructive) { showDiscardAlert = true }
                    .alert("Discard session?", isPresented: $showDiscardAlert) {
                        Button("Discard", role: .destructive) { discard() }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("The tracked time will be lost.")
                    }
                Spacer()
                Button("Cancel") { dismissSelf() }
                    .keyboardShortcut(.escape)
                Button("Log Entry") { stop() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(hours == 0 && minutes == 0)
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func dismissSelf() {
        if let onDismiss { onDismiss() } else { dismiss() }
    }

    private func discard() {
        NotificationManager.shared.cancelSession(id: session.notificationID)
        context.delete(session)
        try? context.save()
        dismissSelf()
    }

    private func stop() {
        let entry = session.asTimeEntry(
            durationMinutes: hours * 60 + minutes,
            notes: notes.isEmpty ? nil : notes
        )
        context.insert(entry)
        NotificationManager.shared.cancelSession(id: session.notificationID)
        context.delete(session)
        try? context.save()
        dismissSelf()
    }
}
