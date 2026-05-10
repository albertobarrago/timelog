//
//  TimeLog2App.swift
//  TimeLog2
//
//  Created by Alberto Barrago on 10/05/2026.
//

import SwiftUI
import SwiftData

@main
struct TimelogApp: App {
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self])
    }
}
