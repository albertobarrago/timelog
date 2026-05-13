import SwiftUI
import SwiftData
import TimelogCore
import AppKit

struct MenuBarView: View {
    @Environment(TimerViewModel.self) private var timerVM
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \ActiveSession.startDate) private var activeSessions: [ActiveSession]
    @Query(sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]
    @Query(filter: #Predicate<Client> { !$0.isArchived }, sort: \Client.name) private var clients: [Client]

    @State private var showingStartTracking = false
    @State private var sessionToStop: ActiveSession?

    private var todayMinutes: Int {
        let logged = allEntries.filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.durationMinutes }
        return logged + activeSessions.reduce(0) { $0 + $1.elapsedMinutes }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact timer row
            CompactTimerRow(vm: timerVM)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // Active sessions
            if !activeSessions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Label("Active", systemImage: "record.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        ForEach(activeSessions) { session in
                            MenuSessionRow(session: session) {
                                sessionToStop = session
                            } onDiscard: {
                                NotificationManager.shared.cancelSession(id: session.notificationID)
                                context.delete(session)
                            }
                        }
                    }
                }
                Divider()
            }

            // Footer
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Today").font(.caption2).foregroundStyle(.secondary)
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text(todayMinutes.formattedDuration)
                            .font(.caption.weight(.semibold)).monospacedDigit()
                    }
                }
                Spacer()
                Button { showingStartTracking = true } label: {
                    Label("Track", systemImage: "play.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open Timelog window")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
        .sheet(isPresented: $showingStartTracking) {
            StartTrackingMacView().environment(settings)
        }
        .sheet(item: $sessionToStop) { StopSessionMacView(session: $0) }
    }
}

private struct CompactTimerRow: View {
    @Bindable var vm: TimerViewModel
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(vm.pomodoroEnabled ? vm.phase.label : "Stopwatch")
                    .font(.caption2).foregroundStyle(.secondary)
                Text(vm.displayTime)
                    .font(.system(size: 22, weight: .light, design: .monospaced))
                    .monospacedDigit()
            }
            Spacer()
            Toggle(isOn: $vm.pomodoroEnabled) {
                Image(systemName: "timer")
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .onChange(of: vm.pomodoroEnabled) { vm.reset() }

            Button { vm.reset() } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(!vm.isRunning && vm.elapsed == 0)

            Button { vm.toggle() } label: {
                Image(systemName: vm.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
        }
    }
}

private struct MenuSessionRow: View {
    let session: ActiveSession
    let onStop: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(session.client?.color ?? .accentColor)
                .frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.client?.name ?? "No client")
                    .font(.caption.weight(.semibold)).lineLimit(1)
                if let proj = session.project {
                    Text(proj.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(session.elapsedDisplay)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(.tint).monospacedDigit()
            Button(action: onStop) {
                Image(systemName: "stop.circle.fill").foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Stop and log")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contextMenu {
            Button("Stop & Log", action: onStop)
            Divider()
            Button("Discard", role: .destructive, action: onDiscard)
        }
    }
}
