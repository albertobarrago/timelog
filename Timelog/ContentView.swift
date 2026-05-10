import TimelogCore
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
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingCompleted },
            set: { if !$0 { onboardingCompleted = true } }
        )) {
            OnboardingView { onboardingCompleted = true }
        }
    }
}
