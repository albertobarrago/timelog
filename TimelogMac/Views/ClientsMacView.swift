import SwiftUI
import SwiftData
import TimelogCore

struct ClientsMacView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var selectedClient: Client?
    @State private var showingAddClient  = false
    @State private var clientToEdit: Client?
    @State private var showArchived      = false

    private var visibleClients: [Client] {
        showArchived ? clients : clients.filter { !$0.isArchived }
    }

    var body: some View {
        HSplitView {
            // ── Clients list ──────────────────────────────
            VStack(spacing: 0) {
                List(visibleClients, selection: $selectedClient) { client in
                    ClientMacRow(client: client)
                        .tag(client)
                        .contextMenu {
                            Button("Edit") { clientToEdit = client }
                            Button(client.isArchived ? "Unarchive" : "Archive") {
                                client.isArchived.toggle()
                            }
                            Divider()
                            Button("Delete", role: .destructive) { context.delete(client) }
                        }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 180, idealWidth: 200, maxWidth: 240)

            // ── Projects detail ───────────────────────────
            if let client = selectedClient {
                ProjectsMacView(client: client)
            } else {
                ContentUnavailableView("Select a client", systemImage: "person.2")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Clients")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showingAddClient = true } label: {
                    Label("Add Client", systemImage: "plus")
                }
                .help("Add a new client")

                Button { showArchived.toggle() } label: {
                    Label(showArchived ? "Hide Archived" : "Show Archived",
                          systemImage: showArchived ? "archivebox.fill" : "archivebox")
                }
                .help(showArchived ? "Hide archived clients" : "Show archived clients")
            }
        }
        .sheet(isPresented: $showingAddClient)  { ClientMacFormView() }
        .sheet(item: $clientToEdit)             { ClientMacFormView(client: $0) }
    }
}

private struct ClientMacRow: View {
    let client: Client
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(client.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(client.name)
                    .foregroundStyle(client.isArchived ? .secondary : .primary)
                Text(client.projects.filter { !$0.isArchived }.count == 1
                     ? "1 project"
                     : "\(client.projects.filter { !$0.isArchived }.count) projects")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if client.isArchived {
                Image(systemName: "archivebox")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ProjectsMacView: View {
    @Environment(\.modelContext) private var context
    let client: Client

    @State private var showingAddProject = false
    @State private var projectToEdit: Project?
    @State private var showArchived      = false
    @State private var selectedProjects  = Set<Project.ID>()

    private var visibleProjects: [Project] {
        client.projects
            .filter { showArchived || !$0.isArchived }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(client.color).frame(width: 10, height: 10)
                Text(client.name).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            if visibleProjects.isEmpty {
                ContentUnavailableView("No projects", systemImage: "folder")
            } else {
                Table(visibleProjects, selection: $selectedProjects) {
                    TableColumn("Project") { proj in
                        HStack(spacing: 6) {
                            Text(proj.name)
                                .foregroundStyle(proj.isArchived ? .secondary : .primary)
                            if let code = proj.code {
                                Text(code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                    }
                    TableColumn("Entries") { proj in
                        Text("\(proj.entries.count)")
                            .foregroundStyle(.secondary)
                    }
                    .width(60)
                    TableColumn("Status") { proj in
                        Text(proj.isArchived ? "Archived" : "Active")
                            .font(.caption)
                            .foregroundStyle(proj.isArchived ? Color.secondary : Color.green)
                    }
                    .width(70)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                Button { showingAddProject = true } label: {
                    Label("Add Project", systemImage: "folder.badge.plus")
                }
                Button { showArchived.toggle() } label: {
                    Label(showArchived ? "Hide Archived" : "Show Archived",
                          systemImage: showArchived ? "eye.slash" : "eye")
                }
            }
        }
        .sheet(isPresented: $showingAddProject) { ProjectMacFormView(client: client) }
        .sheet(item: $projectToEdit)            { ProjectMacFormView(client: client, project: $0) }
    }
}

struct ClientMacFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    var client: Client?

    @State private var name     = ""
    @State private var colorHex = "#007AFF"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(client == nil ? "New Client" : "Edit Client").font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
            ColorPicker("Colour", selection: Binding(
                get: { Color(hex: colorHex) ?? .accentColor },
                set: { colorHex = $0.hex }
            ))
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 280)
        .onAppear { name = client?.name ?? ""; colorHex = client?.colorHex ?? "#007AFF" }
    }

    private func save() {
        if let c = client { c.name = name; c.colorHex = colorHex }
        else { context.insert(Client(name: name, colorHex: colorHex)) }
        dismiss()
    }
}

struct ProjectMacFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    let client: Client
    var project: Project?

    @State private var name = ""
    @State private var code = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(project == nil ? "New Project" : "Edit Project").font(.headline)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            TextField("Code (optional)", text: $code).textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 280)
        .onAppear { name = project?.name ?? ""; code = project?.code ?? "" }
    }

    private func save() {
        if let p = project { p.name = name; p.code = code.isEmpty ? nil : code }
        else {
            let p = Project(name: name, code: code.isEmpty ? nil : code)
            p.client = client
            context.insert(p)
            client.projects.append(p)
        }
        dismiss()
    }
}
