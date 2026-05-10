import SwiftUI
import SwiftData
import TimelogCore

@main
struct TimelogMacApp: App {
    @State private var settings = SettingsStore()
    @State private var timerVM = TimerViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(settings)
                .environment(timerVM)
                .modelContainer(for: [Client.self, Project.self, TimeEntry.self, ActiveSession.self])
                .onAppear {
                    timerVM.applySettings(settings)
                    NotificationManager.shared.requestPermission()
                    settings.applyReminders()
                }
        } label: {
            if timerVM.isRunning {
                Label(timerVM.displayTime, systemImage: "timer")
                    .monospacedDigit()
            } else {
                Image(systemName: "clock")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            MacSettingsView()
                .environment(settings)
                .environment(timerVM)
        }
    }
}
