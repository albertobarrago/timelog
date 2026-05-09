import SwiftUI
import SwiftData

struct ClientsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var showingAddClient = false
    @State private var clientToEdit: Client?

    var body: some View {
        NavigationStack {
            Group {
                if clients.isEmpty {
                    ContentUnavailableView("No clients", systemImage: "person.2",
                        description: Text("Tap + to add your first client"))
                } else {
                    List {
                        ForEach(clients) { client in
                            NavigationLink { ProjectListView(client: client) } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(client.color)
                                        .frame(width: 12, height: 12)
                                    Text(client.name)
                                    Spacer()
                                    if client.isArchived {
                                        Text("Archived")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\(client.projects.filter { !$0.isArchived }.count) projects")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { context.delete(client) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { clientToEdit = client } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    client.isArchived.toggle()
                                } label: {
                                    Label(client.isArchived ? "Unarchive" : "Archive",
                                          systemImage: client.isArchived ? "tray.and.arrow.up" : "archivebox")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Clients")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddClient = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAddClient) { ClientFormView() }
            .sheet(item: $clientToEdit) { ClientFormView(client: $0) }
        }
    }
}
