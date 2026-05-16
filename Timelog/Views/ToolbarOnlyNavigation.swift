import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case today
    case clients
    case timer
    case settings

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .today:    "Today"
        case .clients:  "Clients"
        case .timer:    "Timer"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .today:    "clock"
        case .clients:  "person.2"
        case .timer:    "timer"
        case .settings: "gearshape"
        }
    }
}
