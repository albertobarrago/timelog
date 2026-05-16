import SwiftData
import Foundation

@Model
public final class TimeEntry {
    public var date: Date
    public var durationMinutes: Int
    public var notes: String?
    public var mongoId: String?
    public var client: Client?
    public var project: Project?
    public var deletedAt: Date? = nil

    public init(date: Date = .now, durationMinutes: Int, notes: String? = nil,
                client: Client? = nil, project: Project? = nil) {
        self.date = date
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.client = client
        self.project = project
        self.mongoId = Client.newMongoId()
    }
}
