import Testing
import Foundation
@testable import TimelogCore

@Suite("WidgetSnapshot")
struct WidgetSnapshotTests {

    // MARK: TimelogWidgetActiveSessionSnapshot

    @Test func elapsedMinutesCalculatedFromPastDate() {
        let past = Date(timeIntervalSinceNow: -125)
        let snap = TimelogWidgetActiveSessionSnapshot(startDate: past, clientName: nil, projectName: nil)
        #expect(snap.elapsedMinutes == 2)
    }

    @Test func elapsedMinutesNeverNegativeForFutureDate() {
        let future = Date(timeIntervalSinceNow: 100)
        let snap = TimelogWidgetActiveSessionSnapshot(startDate: future, clientName: nil, projectName: nil)
        #expect(snap.elapsedMinutes == 0)
    }

    @Test func elapsedMinutesZeroForJustStarted() {
        let snap = TimelogWidgetActiveSessionSnapshot(startDate: .now, clientName: nil, projectName: nil)
        #expect(snap.elapsedMinutes == 0)
    }

    // MARK: TimelogWidgetSnapshot aggregations

    @Test func totalMinutesSumsLoggedAndActive() {
        let sessions = [
            TimelogWidgetActiveSessionSnapshot(startDate: Date(timeIntervalSinceNow: -125), clientName: nil, projectName: nil), // 2 min
            TimelogWidgetActiveSessionSnapshot(startDate: Date(timeIntervalSinceNow: -185), clientName: nil, projectName: nil), // 3 min
        ]
        let snapshot = TimelogWidgetSnapshot(
            loggedMinutes: 10,
            activeSessions: sessions,
            lastClientName: nil,
            lastProjectName: nil
        )
        #expect(snapshot.totalMinutes == 15)
    }

    @Test func activeMinutesWithNoSessions() {
        let snapshot = TimelogWidgetSnapshot(
            loggedMinutes: 30,
            activeSessions: [],
            lastClientName: nil,
            lastProjectName: nil
        )
        #expect(snapshot.activeMinutes == 0)
        #expect(snapshot.totalMinutes == 30)
    }

    @Test func emptySnapshotHasZeroMinutes() {
        let empty = TimelogWidgetSnapshot.empty
        #expect(empty.loggedMinutes == 0)
        #expect(empty.activeSessions.isEmpty)
        #expect(empty.totalMinutes == 0)
    }

    // MARK: Codable round-trip

    @Test func codableRoundTrip() throws {
        let original = TimelogWidgetSnapshot(
            date: Date(timeIntervalSince1970: 1_000_000),
            loggedMinutes: 42,
            activeSessions: [
                TimelogWidgetActiveSessionSnapshot(
                    startDate: Date(timeIntervalSince1970: 999_000),
                    clientName: "Acme",
                    projectName: "Website"
                )
            ],
            lastClientName: "Acme",
            lastProjectName: "Website"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TimelogWidgetSnapshot.self, from: data)
        #expect(decoded.loggedMinutes == original.loggedMinutes)
        #expect(decoded.lastClientName == original.lastClientName)
        #expect(decoded.lastProjectName == original.lastProjectName)
        #expect(decoded.activeSessions.count == original.activeSessions.count)
        #expect(decoded.activeSessions.first?.clientName == "Acme")
    }

    @Test func codableRoundTripWithNilFields() throws {
        let original = TimelogWidgetSnapshot(
            loggedMinutes: 0,
            activeSessions: [],
            lastClientName: nil,
            lastProjectName: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TimelogWidgetSnapshot.self, from: data)
        #expect(decoded.lastClientName == nil)
        #expect(decoded.lastProjectName == nil)
    }
}
