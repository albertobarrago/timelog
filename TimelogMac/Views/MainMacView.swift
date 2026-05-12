import SwiftUI
import TimelogCore

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
