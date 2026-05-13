import TimelogCore
import TimelogSync
import SwiftUI
import SwiftData

private struct MongoSyncSetup: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Query private var clients: [Client]
    @Query private var projects: [Project]
    @Query private var entries: [TimeEntry]

    func body(content: Content) -> some View {
        content
            .onAppear {
                let container = modelContext.container
                MongoSyncService.shared.loadConnectionStringFromFile()
                MongoSyncService.shared.setDataProvider { [container] in
                    let ctx = container.mainContext
                    let clients  = (try? ctx.fetch(FetchDescriptor<Client>()))  ?? []
                    let projects = (try? ctx.fetch(FetchDescriptor<Project>())) ?? []
                    let entries  = (try? ctx.fetch(FetchDescriptor<TimeEntry>())) ?? []
                    return (clients, projects, entries)
                }
                Task {
                    try? await MongoSyncService.shared.connect()
                    try? await MongoSyncService.shared.pullAll(into: modelContext)
                    MongoSyncService.shared.triggerSync()
                }
            }
            .onChange(of: clients.count)  { _, _ in MongoSyncService.shared.triggerSync() }
            .onChange(of: projects.count) { _, _ in MongoSyncService.shared.triggerSync() }
            .onChange(of: entries.count)  { _, _ in MongoSyncService.shared.triggerSync() }
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
