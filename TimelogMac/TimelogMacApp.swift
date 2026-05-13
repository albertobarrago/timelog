import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync
import AppKit

private struct MongoSyncSetup: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.onAppear {
            let container = modelContext.container
            MongoSyncService.shared.loadConnectionStringFromFile()
            Task { try? await MongoSyncService.shared.connect() }
            MongoSyncService.shared.startAutoSync { [container] in
                let ctx = container.mainContext
                let clients  = (try? ctx.fetch(FetchDescriptor<Client>()))  ?? []
                let projects = (try? ctx.fetch(FetchDescriptor<Project>())) ?? []
                let entries  = (try? ctx.fetch(FetchDescriptor<TimeEntry>())) ?? []
                return (clients, projects, entries)
            }
        }
    }
}

@main
struct TimelogMacApp: App {
    @State private var settings = SettingsStore()
    @State private var timerVM = TimerViewModel()

    // Single shared container so MenuBarExtra and WindowGroup see the same data
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
                            string: "github.com/AlbertoBarrago",
                            attributes: [
                                .link: URL(string: "https://github.com/AlbertoBarrago")!,
                                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
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
            Image(systemName: "clock")
        }
    }
}
