import TimelogCore
import SwiftUI
import SwiftData

private enum ProjectSheet: Identifiable {
    case add
    case edit(Project)
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let p): return "edit-\(p.persistentModelID)"
        }
    }
}

struct ProjectListView: View {
    @Environment(\.modelContext) private var context
    var client: Client

    @Query(sort: \Project.name) private var allProjects: [Project]
    @State private var activeSheet: ProjectSheet?

    private var activeProjects: [Project] {
        allProjects.filter { $0.client?.persistentModelID == client.persistentModelID && !$0.isArchived }
    }
    private var archivedProjects: [Project] {
        allProjects.filter { $0.client?.persistentModelID == client.persistentModelID && $0.isArchived }
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
                Button { activeSheet = .add } label: { Image(systemName: "plus") }
                    .accessibilityLabel(String(localized: "Add project"))
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add:
                ProjectFormView(client: client)
            case .edit(let p):
                ProjectFormView(client: client, project: p)
            }
        }
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
            Button(role: .destructive) { project.deletedAt = .now } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { activeSheet = .edit(project) } label: {
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
