import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync
import AppKit

private struct MongoSyncSetup: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @State private var showBanner = false

    // @Query is the reliable SwiftData-native way to detect any data change
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
            // Fire push on any insert/delete/update in each collection
            .onChange(of: clients.count)  { _, _ in MongoSyncService.shared.triggerSync() }
            .onChange(of: projects.count) { _, _ in MongoSyncService.shared.triggerSync() }
            .onChange(of: entries.count)  { _, _ in MongoSyncService.shared.triggerSync() }
            .onChange(of: MongoSyncService.shared.lastSyncDate) { _, _ in
                withAnimation(.easeInOut) { showBanner = true }
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation(.easeInOut) { showBanner = false }
                }
            }
            .overlay(alignment: .top) {
                if showBanner {
                    SyncSuccessBanner()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
    }
}

private struct SyncSuccessBanner: View {
    var body: some View {
        Label("Sync completed", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.green.gradient, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
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
