//
//  ContentView.swift
//  TimeLog2
//
//  Created by Alberto Barrago on 10/05/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Today", systemImage: "clock") }
            TimerView()
                .tabItem { Label("Timer", systemImage: "timer") }
            ClientsView()
                .tabItem { Label("Clients", systemImage: "person.2") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
