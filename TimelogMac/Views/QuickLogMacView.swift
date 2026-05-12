import SwiftUI
import SwiftData
import TimelogCore

struct QuickLogMacView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Client> { !$0.isArchived }, sort: \Client.name) private var clients: [Client]

    var entry: TimeEntry?

    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var date = Date()
    @State private var hours = 0
    @State private var minutes = 30
    @State private var notes = ""

    private var availableProjects: [Project] {
        (selectedClient?.projects ?? []).filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry == nil ? "Log Time" : "Edit Entry").font(.headline)

            DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)

            DurationPickerMac(hours: $hours, minutes: $minutes)

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

            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3)

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
        .frame(width: 320)
        .onAppear { populate() }
    }

    private func populate() {
        guard let e = entry else { return }
        date = e.date; hours = e.durationMinutes / 60; minutes = e.durationMinutes % 60
        notes = e.notes ?? ""; selectedClient = e.client; selectedProject = e.project
    }

    private func save() {
        let total = hours * 60 + minutes
        if let e = entry {
            e.date = date; e.durationMinutes = total
            e.notes = notes.isEmpty ? nil : notes
            e.client = selectedClient; e.project = selectedProject
        } else {
            context.insert(TimeEntry(date: date, durationMinutes: total,
                                     notes: notes.isEmpty ? nil : notes,
                                     client: selectedClient, project: selectedProject))
        }
        dismiss()
    }
}
