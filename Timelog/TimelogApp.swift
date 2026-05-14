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
            .onAppear { setupMongoSync() }
            .onChange(of: clients.count)  { _, _ in MongoSyncService.shared.triggerSync() }
            .onChange(of: projects.count) { _, _ in MongoSyncService.shared.triggerSync() }
            .onChange(of: entries.count)  { _, _ in MongoSyncService.shared.triggerSync() }
    }

    private func setupMongoSync() {
        let container = modelContext.container
        let service = MongoSyncService.shared
        service.loadConnectionStringFromFile()
        service.setDataProvider { [container] in
            let ctx = container.mainContext
            let clients  = (try? ctx.fetch(FetchDescriptor<Client>())) ?? []
            let projects = (try? ctx.fetch(FetchDescriptor<Project>())) ?? []
            let entries  = (try? ctx.fetch(FetchDescriptor<TimeEntry>())) ?? []
            return (clients, projects, entries)
        }
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
