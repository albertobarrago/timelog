import TimelogCore
import SwiftUI
import SwiftData

struct ClientsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var showingAddClient = false
    @State private var clientToEdit: Client?
    @State private var showArchived = false

    private var visibleClients: [Client] {
        showArchived ? clients : clients.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleClients.isEmpty {
                    ContentUnavailableView(
                        showArchived ? "No clients" : "No active clients",
                        systemImage: "person.2",
                        description: Text(showArchived ? "Tap + to add your first client" : "All clients are archived")
                    )
                } else {
                    List {
                        ForEach(visibleClients) { client in
                            NavigationLink { ProjectListView(client: client) } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(client.color)
                                        .frame(width: 12, height: 12)
                                    Text(client.name)
                                        .foregroundStyle(client.isArchived ? .secondary : .primary)
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
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showArchived.toggle()
                    } label: {
                        Label(showArchived ? "Hide archived" : "Show archived",
                              systemImage: showArchived ? "archivebox.fill" : "archivebox")
                    }
                }
                #if targetEnvironment(macCatalyst)
                ToolbarItem(placement: .secondaryAction) {
                    TimerQuickToggle()
                }
                #endif
            }
            .sheet(isPresented: $showingAddClient) { ClientFormView() }
            .sheet(item: $clientToEdit) { ClientFormView(client: $0) }
        }
    }
}
