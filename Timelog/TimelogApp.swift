import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync
import UIKit

private struct RestSyncSetup: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Query private var clients:  [Client]
    @Query private var projects: [Project]
    @Query private var entries:  [TimeEntry]
    @State private var isPulling = false

    func body(content: Content) -> some View {
        content
            .onAppear { setup() }
            .onChange(of: clients.count)  { _, _ in if !isPulling { RestSyncService.shared.triggerSync() } }
            .onChange(of: projects.count) { _, _ in if !isPulling { RestSyncService.shared.triggerSync() } }
            .onChange(of: entries.count)  { _, _ in if !isPulling { RestSyncService.shared.triggerSync() } }
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
            isPulling = true
            do {
                try await RestSyncService.shared.pullAll(into: modelContext)
            } catch {
                print("RestSync error: \(error.localizedDescription)")
            }
            isPulling = false
        }
    }
}

// MARK: - Sync flash overlay

private struct SyncFlashOverlay: ViewModifier {
    @State private var flash = false
    private var syncDate: Date? { RestSyncService.shared.lastSyncDate }

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.green.opacity(flash ? 0.18 : 0))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.5), value: flash)
            )
            .onChange(of: RestSyncService.shared.lastSyncDate) { _, _ in
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                flash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { flash = false }
            }
    }
}

@main
struct TimelogApp: App {
    @State private var settings  = SettingsStore()
    @State private var timerVM   = TimerViewModel()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(settings)
                    .environment(timerVM)
                    .onAppear {
                        timerVM.applySettings(settings)
                        NotificationManager.shared.requestPermission()
                        settings.applyReminders()
                    }
                    .modifier(RestSyncSetup())
                    .modifier(SyncFlashOverlay())

                if showSplash {
                    SplashView(isShowing: $showSplash)
                }
            }
        }
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, ActiveSession.self])
    }
}
