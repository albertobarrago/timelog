import SwiftUI
import TimelogCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case today   = "Today"
    case clients = "Clients"
    case timer   = "Timer"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today:   "clock"
        case .clients: "person.2"
        case .timer:   "timer"
        }
    }
}

struct MainMacView: View {
    @State private var selection: SidebarItem = .today

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            switch selection {
            case .today:   TodayMacView()
            case .clients: ClientsMacView()
            case .timer:   TimerMacView()
            }
        }
        .frame(minWidth: 700, minHeight: 460)
    }
}
