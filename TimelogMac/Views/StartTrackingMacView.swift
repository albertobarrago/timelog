import SwiftUI
import SwiftData
import TimelogCore

struct StartTrackingMacView: View {
    var onDismiss: (() -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    @Query(filter: #Predicate<Client> { !$0.isArchived && $0.deletedAt == nil }, sort: \Client.name)
    private var allClients: [Client]
    @Query(filter: #Predicate<Project> { !$0.isArchived && $0.deletedAt == nil }, sort: \Project.name)
    private var allProjects: [Project]

    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var notes = ""

    private var clients: [Client] { allClients.filter { $0.userId == settings.userId } }
    private var availableProjects: [Project] {
        guard let client = selectedClient else { return [] }
        return allProjects.filter { $0.client?.persistentModelID == client.persistentModelID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start Tracking")
                .font(.headline)

            GroupBox(String(localized: "Project")) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Client", selection: $selectedClient) {
                        Text("None").tag(Optional<Client>.none)
                        ForEach(clients) { Text($0.name).tag(Optional($0)) }
                    }
                    .onChange(of: selectedClient) { selectedProject = nil }

                    if !availableProjects.isEmpty {
                        Divider()
                        Picker("Project", selection: $selectedProject) {
                            Text("None").tag(Optional<Project>.none)
                            ForEach(availableProjects) { Text($0.name).tag(Optional($0)) }
                        }
                    }
                }
            }

            GroupBox(String(localized: "Notes")) {
                TextField("Optional", text: $notes)
                    .frame(maxWidth: .infinity)
            }

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
        .frame(width: 320)
    }

    private func dismissSelf() {
        if let onDismiss { onDismiss() } else { dismiss() }
    }

    private func start() {
        let session = ActiveSession(
            client: selectedClient,
            project: selectedProject,
            notes: notes.isEmpty ? nil : notes,
            userId: settings.userId
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
