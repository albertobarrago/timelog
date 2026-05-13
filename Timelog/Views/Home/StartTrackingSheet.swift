import TimelogCore
import SwiftUI
import SwiftData

struct StartTrackingSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    let clients: [Client]

    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var notes = ""

    private var availableProjects: [Project] {
        (selectedClient?.projects ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    Picker("Client", selection: $selectedClient) {
                        Text("None").tag(Optional<Client>.none)
                        ForEach(clients) { Text($0.name).tag(Optional($0)) }
                    }
                    .onChange(of: selectedClient) { selectedProject = nil }

                    if !availableProjects.isEmpty {
                        Picker("Project", selection: $selectedProject) {
                            Text("None").tag(Optional<Project>.none)
                            ForEach(availableProjects) { Text($0.name).tag(Optional($0)) }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Start Tracking")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { start() }
                }
            }
        }
    }

    private func start() {
        let session = ActiveSession(
            client: selectedClient,
            project: selectedProject,
            notes: notes.isEmpty ? nil : notes
        )
        context.insert(session)
        NotificationManager.shared.scheduleSessionOverdue(
            id: session.notificationID,
            clientName: session.client?.name ?? "a project",
            projectName: session.project?.name,
            startDate: session.startDate,
            endHour: settings.trackingEndHour,
            endMinute: settings.trackingEndMinute
        )
        dismiss()
    }
}
