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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self])
    }
}
