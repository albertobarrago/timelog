import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync
import AppKit

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
                    // Pull solo se SwiftData è vuoto (primo avvio / dopo reset manuale).
                    // Se i dati ci sono già, salta il pull per evitare il flash di empty state.
                    let hasData = ((try? container.mainContext.fetch(FetchDescriptor<Client>())) ?? []).count > 0
                    if !hasData {
                        try? await MongoSyncService.shared.pullAll(into: modelContext)
                    }
                    MongoSyncService.shared.triggerSync()
                }
            }
            .onChange(of: clients.count)  { _, _ in MongoSyncService.shared.triggerSync() }
            .onChange(of: projects.count) { _, _ in MongoSyncService.shared.triggerSync() }
            .onChange(of: entries.count)  { _, _ in MongoSyncService.shared.triggerSync() }
    }
}

@main
struct TimelogMacApp: App {
    @State private var settings = SettingsStore()
    @State private var timerVM = TimerViewModel()

    private static let container: ModelContainer = {
        try! ModelContainer(for: Client.self, Project.self, TimeEntry.self, ActiveSession.self)
    }()

    var body: some Scene {
        WindowGroup("Timelog", id: "main") {
            MainMacView()
                .environment(settings)
                .environment(timerVM)
                .onAppear {
                    timerVM.applySettings(settings)
                    NotificationManager.shared.requestPermission()
                    settings.applyReminders()
                }
                .modifier(MongoSyncSetup())
        }
        .modelContainer(Self.container)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About Timelog") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(
                            string: "fatto da un nerd per nerd, il vostro alBz\ngithub.com/AlbertoBarrago",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                                .foregroundColor: NSColor.secondaryLabelColor
                            ]
                        )
                    ])
                }
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environment(settings)
                .environment(timerVM)
        } label: {
            MenuBarStatusLabel(vm: timerVM)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(Self.container)

        Settings {
            MacSettingsView()
                .environment(settings)
                .environment(timerVM)
        }
        .modelContainer(Self.container)
    }
}

private struct MenuBarStatusLabel: View {
    let vm: TimerViewModel
    var body: some View {
        if vm.isRunning {
            Label(vm.displayTime, systemImage: "timer")
                .monospacedDigit()
        } else {
            Label("Timelog", systemImage: "clock")
        }
    }
}
