import SwiftUI
import TimelogCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case today = "Today"
    case clients = "Clients"
    case timer = "Timer"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today: "clock.fill"
        case .clients: "person.2.fill"
        case .timer: "timer"
        }
    }
}

struct MainMacView: View {
    @Environment(TimerViewModel.self) private var timerVM
    @State private var selection: SidebarItem = .today

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(180)
            .listStyle(.sidebar)

            Divider()

            // Mini timer in sidebar
            SidebarTimerWidget(vm: timerVM)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        } detail: {
            switch selection {
            case .today:   TodayMacView()
            case .clients: ClientsMacView()
            case .timer:   TimerMacView()
            }
        }
        .navigationTitle(selection.rawValue)
        .frame(minWidth: 720, minHeight: 480)
    }
}

private struct SidebarTimerWidget: View {
    let vm: TimerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: vm.isRunning ? "record.circle.fill" : "clock")
                    .foregroundStyle(vm.isRunning ? .red : .secondary)
                    .font(.caption)
                Text(vm.isRunning ? "Running" : "Stopped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(vm.displayTime)
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                Button { vm.toggle() } label: {
                    Image(systemName: vm.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button { vm.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!vm.isRunning && vm.elapsed == 0)
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
