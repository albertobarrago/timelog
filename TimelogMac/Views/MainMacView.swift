import SwiftUI
import TimelogCore
import TimelogSync

enum SidebarItem: String, CaseIterable, Identifiable {
    case today    = "Today"
    case history  = "History"
    case clients  = "Clients"
    case timer    = "Timer"
    case settings = "Settings"

    static let primaryItems: [SidebarItem] = [.today, .history, .clients, .timer]

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today:    "clock"
        case .history:  "calendar"
        case .clients:  "person.2"
        case .timer:    "timer"
        case .settings: "gearshape"
        }
    }
}

struct MainMacView: View {
    @State private var selection: SidebarItem = .today
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                List(SidebarItem.primaryItems, selection: $selection) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
                .listStyle(.sidebar)

                Spacer(minLength: 0)

                Divider()
                    .padding(.horizontal, 10)

                Button {
                    selection = .settings
                } label: {
                    Label(SidebarItem.settings.rawValue, systemImage: SidebarItem.settings.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            if selection == .settings {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.accentColor.opacity(0.16))
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == .settings ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)

                MongoStatusDot()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            detailView
        }
        .frame(minWidth: 700, minHeight: 460)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .today:    TodayMacView()
        case .history:  HistoryMacView()
        case .clients:  ClientsMacView()
        case .timer:    TimerMacView()
        case .settings: MacSettingsView()
        }
    }
}

private struct MongoStatusDot: View {
    private var sync: MongoSyncService { MongoSyncService.shared }
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                if sync.isSyncing {
                    Circle()
                        .fill(Color.yellow.opacity(0.25))
                        .frame(width: 14, height: 14)
                        .scaleEffect(pulse ? 1.6 : 1.0)
                        .opacity(pulse ? 0 : 1)
                        .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: pulse)
                }
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
            }
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .onAppear { pulse = true }
    }

    private var dotColor: Color {
        if sync.isSyncing           { return .yellow }
        if sync.lastError != nil    { return .red }
        if sync.lastSyncDate != nil { return .green }
        return Color.secondary.opacity(0.4)
    }

    private var statusText: String {
        if sync.isSyncing        { return "Syncing…" }
        if sync.lastError != nil { return "Sync error" }
        if let d = sync.lastSyncDate {
            return "Synced \(d.formatted(.relative(presentation: .named)))"
        }
        return "Not connected"
    }
}
