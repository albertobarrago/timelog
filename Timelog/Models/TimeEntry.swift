import SwiftData
import Foundation

@Model
final class TimeEntry {
    var date: Date
    var durationMinutes: Int
    var notes: String?
    var client: Client?
    var project: Project?

    init(date: Date = .now, durationMinutes: Int, notes: String? = nil,
         client: Client? = nil, project: Project? = nil) {
        self.date = date
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.client = client
        self.project = project
    }
}
