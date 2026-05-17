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
    @Query private var sessions: [ActiveSession]

    func body(content: Content) -> some View {
        content
            .onAppear {
                let container = modelContext.container
                MongoSyncService.shared.loadConnectionStringFromFile()
                MongoSyncService.shared.setDataProvider { [container] in
                    let ctx = container.mainContext
                    let clients  = (try? ctx.fetch(FetchDescriptor<Client>()))        ?? []
                    let projects = (try? ctx.fetch(FetchDescriptor<Project>()))       ?? []
                    let entries  = (try? ctx.fetch(FetchDescriptor<TimeEntry>()))     ?? []
                    let sessions = (try? ctx.fetch(FetchDescriptor<ActiveSession>())) ?? []
                    return (clients, projects, entries, sessions)
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    try? await MongoSyncService.shared.connect()
                    try? await MongoSyncService.shared.pullAll(into: modelContext)
                    MongoSyncService.shared.triggerSync()
                }
            }
            .onChange(of: dataFingerprint) { _, _ in MongoSyncService.shared.triggerSync() }
    }

    private var dataFingerprint: Int {
        clients.count &+ projects.count &+ entries.count &+ sessions.count
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let ctx = TimelogMacApp.container.mainContext
        let sessions = (try? ctx.fetch(FetchDescriptor<ActiveSession>())) ?? []
        guard !sessions.isEmpty else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "Sessione di tracking in corso"
        alert.informativeText = "Hai \(sessions.count == 1 ? "una sessione attiva" : "\(sessions.count) sessioni attive"). Chiudi l'app comunque?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Chiudi comunque")
        alert.addButton(withTitle: "Annulla")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}

@main
struct TimelogMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var settings = SettingsStore()
    @State private var timerVM = TimerViewModel()

    static let container: ModelContainer = {
        let schema = Schema([Client.self, Project.self, TimeEntry.self, ActiveSession.self])
        let config = ModelConfiguration("TimelogMac", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Store corrotto o incompatibile — reset automatico
            let url = config.url
            try? FileManager.default.removeItem(at: url)
            let base = url.deletingPathExtension()
            try? FileManager.default.removeItem(at: base.appendingPathExtension("store-shm"))
            try? FileManager.default.removeItem(at: base.appendingPathExtension("store-wal"))
            return try! ModelContainer(for: schema, configurations: config)
        }
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
                    MongoSyncService.shared.userId = settings.userId
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
                            string: "Built by alBz — who tracks time obsessively,\nexcept when building this app.\ngithub.com/AlbertoBarrago",
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

    private var iconName: String {
        guard vm.isRunning || vm.elapsed > 0 else { return "clock" }
        guard vm.pomodoroEnabled else { return "stopwatch" }
        switch vm.phase {
        case .work:       return "flame.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak:  return "figure.walk"
        }
    }

    private var iconColor: Color {
        guard vm.isRunning else { return .secondary }
        guard vm.pomodoroEnabled else { return .orange }
        switch vm.phase {
        case .work:       return .red
        case .shortBreak: return .green
        case .longBreak:  return .blue
        }
    }

    var body: some View {
        if vm.isRunning || vm.elapsed > 0 {
            Label(vm.displayTime, systemImage: iconName)
                .monospacedDigit()
                .foregroundStyle(iconColor)
        } else {
            Label("Timelog", systemImage: "clock")
        }
    }
}
