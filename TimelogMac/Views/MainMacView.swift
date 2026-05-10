import SwiftUI
import TimelogCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case today    = "Today"
    case clients  = "Clients"
    case timer    = "Timer"
    case settings = "Settings"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today:    "clock"
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
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            switch selection {
            case .today:    TodayMacView()
            case .clients:  ClientsMacView()
            case .timer:    TimerMacView()
            case .settings: MacSettingsView()
            }
        }
        .frame(minWidth: 700, minHeight: 460)
    }
}
