import SwiftData

@Model
final class Project {
    var name: String
    var code: String?
    var isArchived: Bool
    var client: Client?
    @Relationship(deleteRule: .cascade) var entries: [TimeEntry] = []

    init(name: String, code: String? = nil, isArchived: Bool = false) {
        self.name = name
        self.code = code
        self.isArchived = isArchived
    }
}
