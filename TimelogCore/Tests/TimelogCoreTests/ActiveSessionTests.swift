import Testing
import Foundation
import SwiftData
@testable import TimelogCore

@Suite("ActiveSession")
@MainActor
struct ActiveSessionTests {

    // MARK: elapsedMinutes (non richiede ModelContainer — accede solo a startDate)

    @Test func elapsedMinutesRoundsDown() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        session.startDate = Date(timeIntervalSinceNow: -125)
        #expect(session.elapsedMinutes == 2)
    }

    @Test func elapsedMinutesNeverNegative() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        session.startDate = Date(timeIntervalSinceNow: 100)
        #expect(session.elapsedMinutes == 0)
    }

    @Test func elapsedMinutesZeroForJustStarted() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        #expect(session.elapsedMinutes == 0)
    }

    // MARK: elapsedDisplay

    @Test func elapsedDisplayMMSSFormatUnderOneHour() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        session.startDate = Date(timeIntervalSinceNow: -30)
        let colons = session.elapsedDisplay.filter { $0 == ":" }.count
        #expect(colons == 1)
    }

    @Test func elapsedDisplayHHMMSSFormatOverOneHour() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        session.startDate = Date(timeIntervalSinceNow: -3700)
        let colons = session.elapsedDisplay.filter { $0 == ":" }.count
        #expect(colons == 2)
    }

    // MARK: asTimeEntry

    @Test func asTimeEntryPreservesFields() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        let entry = session.asTimeEntry(durationMinutes: 45, notes: "standup")
        #expect(entry.durationMinutes == 45)
        #expect(entry.notes == "standup")
        #expect(entry.date == session.startDate)
    }

    @Test func asTimeEntryNilNotes() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        let entry = session.asTimeEntry(durationMinutes: 10, notes: nil)
        #expect(entry.notes == nil)
    }
}
