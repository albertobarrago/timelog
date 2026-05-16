import SwiftUI
import SwiftData
import TimelogCore

struct StartTrackingMacView: View {
    var onDismiss: (() -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    @Query(filter: #Predicate<Client> { !$0.isArchived }, sort: \Client.name)
    private var clients: [Client]

    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var notes = ""

    private var availableProjects: [Project] {
        (selectedClient?.projects ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start Tracking")
                .font(.headline)

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

            TextField("Notes (optional)", text: $notes)

            HStack {
                Button("Cancel") { dismissSelf() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Start") { start() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 280)
    }

    private func dismissSelf() {
        if let onDismiss { onDismiss() } else { dismiss() }
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
        dismissSelf()
    }
}
