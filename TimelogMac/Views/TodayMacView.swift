import SwiftUI
import SwiftData
import TimelogCore

struct TodayMacView: View {
    @Environment(\.modelContext) private var context
    @Environment(TimerViewModel.self) private var timerVM
    @Environment(SettingsStore.self) private var settings
    @Query(sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]
    @Query(sort: \ActiveSession.startDate) private var activeSessions: [ActiveSession]
    @Query(filter: #Predicate<Client> { !$0.isArchived }, sort: \Client.name) private var clients: [Client]

    @State private var showingQuickLog = false
    @State private var showingStartTracking = false
    @State private var entryToEdit: TimeEntry?
    @State private var sessionToStop: ActiveSession?

    private var todayEntries: [TimeEntry] {
        allEntries.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todayTotal: Int {
        todayEntries.reduce(0) { $0 + $1.durationMinutes }
        + activeSessions.reduce(0) { $0 + $1.elapsedMinutes }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(todayTotal.formattedDuration)
                            .font(.title2.bold().monospacedDigit())
                    }
                    Spacer()
                    if !activeSessions.isEmpty {
                        Label("\(activeSessions.count) active", systemImage: "record.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .background(.bar)

            Divider()

            if activeSessions.isEmpty && todayEntries.isEmpty {
                ContentUnavailableView {
                    Label("No entries today", systemImage: "clock")
                } description: {
                    Text("Use the toolbar to log time or start tracking a session.")
                } actions: {
                    Button("Log Time") { showingQuickLog = true }
                    Button("Start Tracking") { showingStartTracking = true }
                }
            } else {
                List {
                    if !activeSessions.isEmpty {
                        Section("Active Sessions") {
                            TimelineView(.periodic(from: .now, by: 1)) { _ in
                                ForEach(activeSessions) { session in
                                    ActiveSessionMacRow(session: session)
                                        .onTapGesture { sessionToStop = session }
                                        .contextMenu {
                                            Button("Stop & Log") { sessionToStop = session }
                                            Divider()
                                            Button("Discard", role: .destructive) {
                                                NotificationManager.shared.cancelSession(id: session.notificationID)
                                                context.delete(session)
                                            }
                                        }
                                }
                            }
                        }
                    }

                    Section("Entries") {
                        ForEach(todayEntries) { entry in
                            EntryMacRow(entry: entry)
                                .onTapGesture { entryToEdit = entry }
                                .contextMenu {
                                    Button("Edit") { entryToEdit = entry }
                                    Divider()
                                    Button("Delete", role: .destructive) { context.delete(entry) }
                                }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingStartTracking = true } label: {
                    Label("Start Tracking", systemImage: "play.circle")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showingQuickLog = true } label: {
                    Label("Log Time", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingQuickLog) { QuickLogMacView() }
        .sheet(isPresented: $showingStartTracking) { StartTrackingMacView(clients: clients).environment(settings) }
        .sheet(item: $entryToEdit) { QuickLogMacView(entry: $0) }
        .sheet(item: $sessionToStop) { StopSessionMacView(session: $0) }
    }
}

struct ActiveSessionMacRow: View {
    let session: ActiveSession
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(session.client?.color ?? .accentColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.client?.name ?? "No client")
                    .fontWeight(.medium)
                if let proj = session.project {
                    Text(proj.name).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(session.elapsedDisplay)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.tint)
                .monospacedDigit()
            Image(systemName: "stop.circle.fill").foregroundStyle(.red)
        }
        .padding(.vertical, 2)
    }
}

struct EntryMacRow: View {
    let entry: TimeEntry
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(entry.client?.color ?? Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.client?.name ?? "No client").fontWeight(.medium)
                if let proj = entry.project {
                    Text(proj.name).font(.caption).foregroundStyle(.secondary)
                }
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(entry.durationMinutes.formattedDuration)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}
