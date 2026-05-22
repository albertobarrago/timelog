import SwiftUI
import SwiftData
import TimelogCore

struct QuickLogMacView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<Client> { !$0.isArchived && $0.deletedAt == nil }, sort: \Client.name) private var allClients: [Client]
    @Query(filter: #Predicate<Project> { !$0.isArchived && $0.deletedAt == nil }, sort: \Project.name) private var allProjects: [Project]

    var entry: TimeEntry?

    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var date = Date()
    @State private var hours = 0
    @State private var minutes = 30
    @State private var notes = ""

    private var clients: [Client] { allClients.filter { $0.userId == settings.userId } }
    private var availableProjects: [Project] {
        guard let client = selectedClient else { return [] }
        return allProjects.filter { $0.client?.persistentModelID == client.persistentModelID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry == nil ? "Log Time" : "Edit Entry")
                .font(.headline)

            GroupBox(String(localized: "When")) {
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(String(localized: "Duration")) {
                DurationPickerMac(hours: $hours, minutes: $minutes)
            }

            GroupBox(String(localized: "Project")) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Client", selection: $selectedClient) {
                        Text("None").tag(Optional<Client>.none)
                        ForEach(clients) { Text($0.name).tag(Optional($0)) }
                    }
                    .onChange(of: selectedClient) { _, newClient in
                        if selectedProject?.client?.persistentModelID != newClient?.persistentModelID {
                            selectedProject = nil
                        }
                    }

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
                TextField("Optional", text: $notes, axis: .vertical)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity)
            }

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(hours == 0 && minutes == 0)
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear { populate() }
    }

    private func populate() {
        guard let e = entry else { return }
        date = e.date
        hours = e.durationMinutes / 60
        minutes = e.durationMinutes % 60
        notes = e.notes ?? ""
        selectedClient = e.client
        selectedProject = e.project
    }

    private func save() {
        let total = hours * 60 + minutes
        if let e = entry {
            e.date = date
            e.durationMinutes = total
            e.notes = notes.isEmpty ? nil : notes
            e.client = selectedClient
            e.project = selectedProject
        } else {
            context.insert(TimeEntry(date: date, durationMinutes: total,
                                     notes: notes.isEmpty ? nil : notes,
                                     client: selectedClient, project: selectedProject,
                                     userId: settings.userId))
        }
        try? context.save()
        dismiss()
    }
}
