import TimelogCore
import SwiftUI
import SwiftData
#if os(iOS)
import WidgetKit
#endif

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]
    @Query(sort: \ActiveSession.startDate) private var activeSessions: [ActiveSession]
    @State private var activeSheet: HomeSheet?

    private var todayEntries: [TimeEntry] {
        allEntries.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var widgetSnapshotSignature: String {
        let entryPart = todayEntries
            .map { "\($0.persistentModelID):\($0.durationMinutes):\($0.date.timeIntervalSince1970)" }
            .joined(separator: "|")
        let sessionPart = activeSessions
            .map { "\($0.persistentModelID):\($0.startDate.timeIntervalSince1970)" }
            .joined(separator: "|")
        return "\(entryPart)#\(sessionPart)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    let loggedMinutes = todayEntries.reduce(0) { $0 + $1.durationMinutes }
                    let activeMinutes = activeSessions.reduce(0) { $0 + $1.elapsedMinutes }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text((loggedMinutes + activeMinutes).formattedDuration)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        Image(systemName: activeSessions.isEmpty ? "clock.fill" : "record.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(activeSessions.isEmpty ? Color.secondary.opacity(0.4) : Color.red.opacity(0.7))
                    }
                    .padding()
                    .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                }

                if activeSessions.isEmpty && todayEntries.isEmpty {
                    ContentUnavailableView(
                        "No entries today",
                        systemImage: "clock",
                        description: Text("Tap + to log time or ▶ to start tracking")
                    )
                } else {
                    List {
                        if !activeSessions.isEmpty {
                            Section("Active") {
                                ForEach(activeSessions) { session in
                                    ActiveSessionRow(session: session)
                                        .contentShape(Rectangle())
                                        .onTapGesture { activeSheet = .stopSession(session) }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                NotificationManager.shared.cancelSession(id: session.notificationID)
                                                context.delete(session)
                                            } label: {
                                                Label("Discard", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }

                        ForEach(todayEntries) { entry in
                            EntryRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture { activeSheet = .editEntry(entry) }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        context.delete(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("Timelog")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { activeSheet = .history } label: {
                        Image(systemName: "calendar")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { activeSheet = .startTracking } label: {
                        Image(systemName: "play.circle")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { activeSheet = .quickLog } label: {
                        Image(systemName: "plus")
                    }
                }
                #if targetEnvironment(macCatalyst)
                ToolbarItem(placement: .secondaryAction) {
                    TimerQuickToggle()
                }
                #endif
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .quickLog:
                    QuickLogSheet()
                case .startTracking:
                    StartTrackingSheet()
                case .history:
                    HistoryView()
                case .editEntry(let entry):
                    QuickLogSheet(entry: entry)
                case .stopSession(let session):
                    StopSessionSheet(session: session)
                }
            }
            .onAppear { updateWidgetSnapshot() }
            .onChange(of: widgetSnapshotSignature) { updateWidgetSnapshot() }
        }
    }

    private func updateWidgetSnapshot() {
        let latestEntry = todayEntries.first
        let latestSession = activeSessions.max { $0.startDate < $1.startDate }
        let snapshot = TimelogWidgetSnapshot(
            loggedMinutes: todayEntries.reduce(0) { $0 + $1.durationMinutes },
            activeSessions: activeSessions.map {
                TimelogWidgetActiveSessionSnapshot(
                    startDate: $0.startDate,
                    clientName: $0.client?.name,
                    projectName: $0.project?.name
                )
            },
            lastClientName: latestSession?.client?.name ?? latestEntry?.client?.name,
            lastProjectName: latestSession?.project?.name ?? latestEntry?.project?.name
        )
        WidgetSnapshotStore.save(snapshot)
        #if os(iOS)
        WidgetCenter.shared.reloadTimelines(ofKind: TimelogWidgetConstants.kind)
        #endif
    }
}

private enum HomeSheet: Identifiable {
    case quickLog
    case startTracking
    case history
    case editEntry(TimeEntry)
    case stopSession(ActiveSession)

    var id: String {
        switch self {
        case .quickLog: "quickLog"
        case .startTracking: "startTracking"
        case .history: "history"
        case .editEntry(let entry): "editEntry-\(entry.persistentModelID)"
        case .stopSession(let session): "stopSession-\(session.persistentModelID)"
        }
    }
}

private struct ActiveSessionRow: View {
    let session: ActiveSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(session.client?.color ?? .accentColor)
                    .frame(width: 4, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.client?.name ?? "No client")
                        .font(.subheadline.weight(.semibold))
                    if let proj = session.project {
                        Text(proj.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(session.elapsedDisplay)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.tint)

                Image(systemName: "stop.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
            }
            .padding(.vertical, 2)
        }
    }
}

private struct EntryRow: View {
    let entry: TimeEntry

    var body: some View {
        HStack(spacing: 12) {
            if let color = entry.client?.color {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 4, height: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.client?.name ?? "No client")
                    .font(.subheadline.weight(.semibold))
                if let proj = entry.project {
                    Text(proj.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(entry.durationMinutes.formattedDuration)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
