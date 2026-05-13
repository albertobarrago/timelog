import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync

private struct MongoSyncSetup: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Query private var clients: [Client]
    @Query private var projects: [Project]
    @Query private var entries: [TimeEntry]

    func body(content: Content) -> some View {
        content
            .onAppear {
                setupMongoSync()
            }
            // Modern iOS 17+ onChange syntax
            .onChange(of: clients.count)  { _, _ in triggerSync() }
            .onChange(of: projects.count) { _, _ in triggerSync() }
            .onChange(of: entries.count)  { _, _ in triggerSync() }
    }

    private func setupMongoSync() {
        let container = modelContext.container
        let service = MongoSyncService.shared
        
        service.loadConnectionStringFromFile()
        
        // Provide the data to the sync service
        service.setDataProvider { [container] in
            let ctx = container.mainContext
            let clients = (try? ctx.fetch(FetchDescriptor<Client>())) ?? []
            let projects = (try? ctx.fetch(FetchDescriptor<Project>())) ?? []
            let entries = (try? ctx.fetch(FetchDescriptor<TimeEntry>())) ?? []
            return (clients, projects, entries)
        }

        // Perform initial connection and pull
        Task {
            do {
                try await service.connect()
                try await service.pullAll(into: modelContext)
                service.triggerSync()
            } catch {
                print("MongoDB Sync Error: \(error.localizedDescription)")
            }
        }
    }

    private func triggerSync() {
        MongoSyncService.shared.triggerSync()
    }
}

@main
struct TimelogApp: App {
    @State private var settings = SettingsStore()
    @State private var timerVM = TimerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(timerVM)
                .onAppear {
                    timerVM.applySettings(settings)
                    NotificationManager.shared.requestPermission()
                    settings.applyReminders()
                }
                .modifier(MongoSyncSetup())
        }
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, ActiveSession.self])
    }
}
