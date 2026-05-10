import SwiftUI

struct ContentView: View {
    @Environment(TimerViewModel.self) private var timerVM
    @State private var selectedTab = 0
    @AppStorage("onboarding_completed") private var onboardingCompleted = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Today", systemImage: "clock") }
                .tag(0)
            ClientsView()
                .tabItem { Label("Clients", systemImage: "person.2") }
                .tag(1)
            TimerView()
                .tabItem { Label("Timer", systemImage: "timer") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                TimerToolbarButton(selectedTab: $selectedTab)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingCompleted },
            set: { if !$0 { onboardingCompleted = true } }
        )) {
            OnboardingView { onboardingCompleted = true }
        }
    }
}

private struct TimerToolbarButton: View {
    @Environment(TimerViewModel.self) private var vm
    @Binding var selectedTab: Int

    var body: some View {
        Button {
            if selectedTab == 2 {
                vm.toggle()
            } else {
                selectedTab = 2
            }
        } label: {
            if vm.isRunning {
                Label(vm.displayTime, systemImage: "timer")
                    .monospacedDigit()
                    .foregroundStyle(.tint)
            } else {
                Label("Timer", systemImage: "timer")
            }
        }
        .help(vm.isRunning ? "Pause timer" : selectedTab == 2 ? "Start timer" : "Open Timer")
    }
}
