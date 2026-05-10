import SwiftUI
import SwiftData
import TimelogCore

struct ClientsMacView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var selectedClient: Client?
    @State private var showingAddClient = false
    @State private var clientToEdit: Client?
    @State private var showingAddProject = false
    @State private var showArchived = false

    private var visibleClients: [Client] {
        showArchived ? clients : clients.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationSplitView {
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
            .navigationSplitViewColumnWidth(220)
            .toolbar {
                ToolbarItem {
                    Button { showingAddClient = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem {
                    Button { showArchived.toggle() } label: {
                        Image(systemName: showArchived ? "archivebox.fill" : "archivebox")
                    }
                    .help(showArchived ? "Hide archived" : "Show archived")
                }
            }
        } detail: {
            if let client = selectedClient {
                ProjectsMacView(client: client)
            } else {
                ContentUnavailableView("Select a client", systemImage: "person.2")
            }
        }
        .sheet(isPresented: $showingAddClient) { ClientMacFormView() }
        .sheet(item: $clientToEdit) { ClientMacFormView(client: $0) }
    }
}

private struct ClientMacRow: View {
    let client: Client
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(client.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                    .foregroundStyle(client.isArchived ? .secondary : .primary)
                Text("\(client.projects.filter { !$0.isArchived }.count) projects")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if client.isArchived {
                Spacer()
                Image(systemName: "archivebox").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ProjectsMacView: View {
    @Environment(\.modelContext) private var context
    let client: Client

    @State private var showingAddProject = false
    @State private var projectToEdit: Project?
    @State private var showArchived = false

    private var visibleProjects: [Project] {
        let all = client.projects.sorted { $0.name < $1.name }
        return showArchived ? all : all.filter { !$0.isArchived }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(client.color).frame(width: 12, height: 12)
                Text(client.name).font(.title3.weight(.semibold))
                Spacer()
            }
            .padding()

            Divider()

            if visibleProjects.isEmpty {
                ContentUnavailableView("No projects", systemImage: "folder")
            } else {
                Table(visibleProjects) {
                    TableColumn("Project") { proj in
                        HStack {
                            Text(proj.name)
                            if let code = proj.code {
                                Text(code).font(.caption).foregroundStyle(.secondary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                    }
                    TableColumn("Status") { proj in
                        Text(proj.isArchived ? "Archived" : "Active")
                            .foregroundStyle(proj.isArchived ? Color.secondary : Color.green)
                    }
                    .width(80)
                    TableColumn("Entries") { proj in
                        Text("\(proj.entries.count)")
                            .foregroundStyle(.secondary)
                    }
                    .width(60)
                }
                .contextMenu(forSelectionType: Project.self) { projects in
                    Button("Archive / Unarchive") {
                        projects.forEach { $0.isArchived.toggle() }
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        projects.forEach { context.delete($0) }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddProject = true } label: {
                    Label("Add Project", systemImage: "plus")
                }
            }
            ToolbarItem {
                Button { showArchived.toggle() } label: {
                    Image(systemName: showArchived ? "archivebox.fill" : "archivebox")
                }
                .help(showArchived ? "Hide archived" : "Show archived")
            }
        }
        .sheet(isPresented: $showingAddProject) { ProjectMacFormView(client: client) }
        .sheet(item: $projectToEdit) { ProjectMacFormView(client: client, project: $0) }
    }
}

struct ClientMacFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var client: Client?

    @State private var name = ""
    @State private var colorHex = "#007AFF"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(client == nil ? "New Client" : "Edit Client").font(.headline)
            TextField("Name", text: $name)
            ColorPicker("Color", selection: Binding(
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
        .padding()
        .frame(width: 280)
        .onAppear {
            name = client?.name ?? ""
            colorHex = client?.colorHex ?? "#007AFF"
        }
    }

    private func save() {
        if let client {
            client.name = name; client.colorHex = colorHex
        } else {
            context.insert(Client(name: name, colorHex: colorHex))
        }
        dismiss()
    }
}

struct ProjectMacFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let client: Client
    var project: Project?

    @State private var name = ""
    @State private var code = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(project == nil ? "New Project" : "Edit Project").font(.headline)
            TextField("Name", text: $name)
            TextField("Code (optional)", text: $code)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            name = project?.name ?? ""
            code = project?.code ?? ""
        }
    }

    private func save() {
        if let project {
            project.name = name; project.code = code.isEmpty ? nil : code
        } else {
            let p = Project(name: name, code: code.isEmpty ? nil : code)
            p.client = client
            context.insert(p)
            client.projects.append(p)
        }
        dismiss()
    }
}
