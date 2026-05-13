import TimelogCore
import TimelogSync
import SwiftUI
import SwiftData

private struct MongoSyncSetup: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.onAppear {
            MongoSyncService.shared.startAutoSync {
                let clients  = (try? modelContext.fetch(FetchDescriptor<Client>()))  ?? []
                let projects = (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
                let entries  = (try? modelContext.fetch(FetchDescriptor<TimeEntry>())) ?? []
                return (clients, projects, entries)
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
