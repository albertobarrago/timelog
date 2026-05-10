import TimelogCore
import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var context
    var client: Client

    @State private var showingAddProject = false
    @State private var projectToEdit: Project?

    private var activeProjects: [Project] {
        client.projects.filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }
    private var archivedProjects: [Project] {
        client.projects.filter { $0.isArchived }.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            if activeProjects.isEmpty && archivedProjects.isEmpty {
                ContentUnavailableView("No projects", systemImage: "folder",
                    description: Text("Tap + to add a project"))
            }

            if !activeProjects.isEmpty {
                Section("Active") {
                    ForEach(activeProjects, content: projectRow)
                }
            }
            if !archivedProjects.isEmpty {
                Section("Archived") {
                    ForEach(archivedProjects, content: projectRow)
                }
            }
        }
        .navigationTitle(client.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddProject = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAddProject) { ProjectFormView(client: client) }
        .sheet(item: $projectToEdit) { ProjectFormView(client: client, project: $0) }
    }

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        HStack {
            Text(project.name)
            if let code = project.code {
                Text(code)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15), in: Capsule())
            }
            Spacer()
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { context.delete(project) } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { projectToEdit = project } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                project.isArchived.toggle()
            } label: {
                Label(project.isArchived ? "Unarchive" : "Archive",
                      systemImage: project.isArchived ? "tray.and.arrow.up" : "archivebox")
            }
            .tint(.orange)
        }
    }
}
