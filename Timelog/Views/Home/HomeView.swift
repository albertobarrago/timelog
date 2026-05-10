import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]
    @Query(sort: \ActiveSession.startDate) private var activeSessions: [ActiveSession]
    @State private var showingQuickLog = false
    @State private var showingStartTracking = false
    @State private var entryToEdit: TimeEntry?
    @State private var sessionToStop: ActiveSession?

    private var todayEntries: [TimeEntry] {
        allEntries.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var totalMinutes: Int {
        todayEntries.reduce(0) { $0 + $1.durationMinutes }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(totalMinutes.formattedDuration)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Image(systemName: "clock.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary.opacity(0.4))
                }
                .padding()
                .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
                .padding()

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
                                        .onTapGesture { sessionToStop = session }
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
                                .onTapGesture { entryToEdit = entry }
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
                    Button { showingStartTracking = true } label: {
                        Image(systemName: "play.circle")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingQuickLog = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingQuickLog) { QuickLogSheet() }
            .sheet(isPresented: $showingStartTracking) { StartTrackingSheet() }
            .sheet(item: $entryToEdit) { QuickLogSheet(entry: $0) }
            .sheet(item: $sessionToStop) { StopSessionSheet(session: $0) }
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
