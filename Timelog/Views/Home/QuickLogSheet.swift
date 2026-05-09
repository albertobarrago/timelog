import SwiftUI
import SwiftData

struct QuickLogSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Client> { !$0.isArchived }, sort: \Client.name)
    private var clients: [Client]

    var entry: TimeEntry?

    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var date = Date()
    @State private var hours = 0
    @State private var minutes = 30
    @State private var notes = ""

    private var availableProjects: [Project] {
        (selectedClient?.projects ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Duration") {
                    HStack(spacing: 16) {
                        Picker("Hours", selection: $hours) {
                            ForEach(0..<24, id: \.self) { Text("\($0)h").tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)

                        Picker("Min", selection: $minutes) {
                            ForEach([0, 15, 30, 45], id: \.self) { Text("\($0)m").tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                }

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
            .navigationTitle(entry == nil ? "Log Time" : "Edit Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(hours == 0 && minutes == 0)
                }
            }
            .onAppear { populateIfEditing() }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 440)
        #endif
    }

    private func populateIfEditing() {
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
            let e = TimeEntry(
                date: date, durationMinutes: total,
                notes: notes.isEmpty ? nil : notes,
                client: selectedClient, project: selectedProject
            )
            context.insert(e)
        }
        dismiss()
    }
}
