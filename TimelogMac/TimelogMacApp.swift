import SwiftUI
import SwiftData
import TimelogCore

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
        }
        .modelContainer(Self.container)
        .commands {
            CommandGroup(replacing: .newItem) {}
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
