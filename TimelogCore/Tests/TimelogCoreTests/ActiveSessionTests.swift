import Testing
import Foundation
import SwiftData
@testable import TimelogCore

@Suite("ActiveSession")
struct ActiveSessionTests {

    @MainActor
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        return container.mainContext
    }

    @Test @MainActor func elapsedDisplayMMSSFormatUnderOneHour() throws {
        let ctx = try makeContext()
        let session = ActiveSession()
        ctx.insert(session)
        session.startDate = Date(timeIntervalSinceNow: -30)
        let colons = session.elapsedDisplay.filter { $0 == ":" }.count
        #expect(colons == 1)
    }

    @Test @MainActor func elapsedDisplayHHMMSSFormatOverOneHour() throws {
        let ctx = try makeContext()
        let session = ActiveSession()
        ctx.insert(session)
        session.startDate = Date(timeIntervalSinceNow: -3700)
        let colons = session.elapsedDisplay.filter { $0 == ":" }.count
        #expect(colons == 2)
    }

    @Test @MainActor func elapsedMinutesRoundsDown() throws {
        let ctx = try makeContext()
        let session = ActiveSession()
        ctx.insert(session)
        session.startDate = Date(timeIntervalSinceNow: -125)
        #expect(session.elapsedMinutes == 2)
    }

    @Test @MainActor func elapsedMinutesNeverNegative() throws {
        let ctx = try makeContext()
        let session = ActiveSession()
        ctx.insert(session)
        session.startDate = Date(timeIntervalSinceNow: 100)
        #expect(session.elapsedMinutes == 0)
    }

    @Test @MainActor func asTimeEntryPreservesFields() throws {
        let ctx = try makeContext()
        let session = ActiveSession()
        ctx.insert(session)
        let entry = session.asTimeEntry(durationMinutes: 45, notes: "standup")
        #expect(entry.durationMinutes == 45)
        #expect(entry.notes == "standup")
        #expect(entry.date == session.startDate)
    }

    @Test @MainActor func asTimeEntryNilNotes() throws {
        let ctx = try makeContext()
        let session = ActiveSession()
        ctx.insert(session)
        let entry = session.asTimeEntry(durationMinutes: 10, notes: nil)
        #expect(entry.notes == nil)
    }
}
