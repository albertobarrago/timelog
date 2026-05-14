import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync

private struct RestSyncSetup: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Query private var clients:  [Client]
    @Query private var projects: [Project]
    @Query private var entries:  [TimeEntry]

    func body(content: Content) -> some View {
        content
            .onAppear { setup() }
            .onChange(of: clients.count)  { _, _ in RestSyncService.shared.triggerSync() }
            .onChange(of: projects.count) { _, _ in RestSyncService.shared.triggerSync() }
            .onChange(of: entries.count)  { _, _ in RestSyncService.shared.triggerSync() }
    }

    private func setup() {
        RestSyncService.shared.loadConfigFromFile()
        let container = modelContext.container
        RestSyncService.shared.setDataProvider { [container] in
            let ctx = container.mainContext
            return (
                (try? ctx.fetch(FetchDescriptor<Client>())) ?? [],
                (try? ctx.fetch(FetchDescriptor<Project>())) ?? [],
                (try? ctx.fetch(FetchDescriptor<TimeEntry>())) ?? []
            )
        }
        guard RestSyncService.shared.isConfigured else { return }
        Task {
            do {
                try await RestSyncService.shared.pullAll(into: modelContext)
                RestSyncService.shared.triggerSync()
            } catch {
                print("RestSync error: \(error.localizedDescription)")
            }
        }
    }
}

@main
struct TimelogApp: App {
    @State private var settings = SettingsStore()
    @State private var timerVM  = TimerViewModel()

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
                .modifier(RestSyncSetup())
        }
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, ActiveSession.self])
    }
}
