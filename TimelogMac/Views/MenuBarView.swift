import SwiftUI
import SwiftData
import TimelogCore

struct MenuBarView: View {
    @Environment(TimerViewModel.self) private var timerVM
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var context
    @Query(sort: \ActiveSession.startDate) private var activeSessions: [ActiveSession]
    @Query(sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]
    @Query(filter: #Predicate<Client> { !$0.isArchived }, sort: \Client.name) private var clients: [Client]

    @State private var showingStartTracking = false
    @State private var sessionToStop: ActiveSession?

    private var todayMinutes: Int {
        let logged = allEntries
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.durationMinutes }
        let active = activeSessions.reduce(0) { $0 + $1.elapsedMinutes }
        return logged + active
    }

    var body: some View {
        VStack(spacing: 0) {
            // Timer section
            TimerSection(vm: timerVM)
                .padding()

            Divider()

            // Active sessions
            if !activeSessions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        ForEach(activeSessions) { session in
                            SessionRow(session: session) {
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text(todayMinutes.formattedDuration)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                }

                Spacer()

                Button {
                    showingStartTracking = true
                } label: {
                    Label("Track", systemImage: "play.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .frame(width: 300)
        .sheet(isPresented: $showingStartTracking) {
            StartTrackingMacView(clients: clients)
                .environment(settings)
        }
        .sheet(item: $sessionToStop) { session in
            StopSessionMacView(session: session)
        }
    }
}

private struct TimerSection: View {
    @Bindable var vm: TimerViewModel

    var body: some View {
        HStack(spacing: 16) {
            Text(vm.displayTime)
                .font(.system(size: 32, weight: .thin, design: .monospaced))
                .monospacedDigit()

            Spacer()

            Button { vm.reset() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button { vm.toggle() } label: {
                Image(systemName: vm.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])

            Toggle(isOn: $vm.pomodoroEnabled) {
                Image(systemName: "timer")
            }
            .toggleStyle(.button)
            .onChange(of: vm.pomodoroEnabled) { vm.reset() }
        }
    }
}

private struct SessionRow: View {
    let session: ActiveSession
    let onStop: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(session.client?.color ?? .accentColor)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.client?.name ?? "No client")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if let proj = session.project {
                    Text(proj.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(session.elapsedDisplay)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(.tint)
                .monospacedDigit()

            Button(action: onStop) {
                Image(systemName: "stop.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Stop and log")
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .contextMenu {
            Button("Discard", role: .destructive, action: onDiscard)
        }
    }
}
