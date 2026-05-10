import SwiftData
import Foundation

@Model
final class ActiveSession {
    var startDate: Date
    var client: Client?
    var project: Project?
    var notes: String?
    var notificationID: String

    init(client: Client? = nil, project: Project? = nil, notes: String? = nil) {
        self.startDate = .now
        self.client = client
        self.project = project
        self.notes = notes
        self.notificationID = UUID().uuidString
    }

    var elapsedDisplay: String {
        let s = Int(Date().timeIntervalSince(startDate))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }

    var elapsedMinutes: Int {
        max(0, Int(Date().timeIntervalSince(startDate) / 60))
    }
}
