import SwiftData
import Foundation

@Model
public final class Project {
    public var name: String
    public var code: String?
    public var isArchived: Bool
    public var mongoId: String?
    public var client: Client?
    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.project) public var entries: [TimeEntry] = []

    public init(name: String, code: String? = nil, isArchived: Bool = false) {
        self.name = name
        self.code = code
        self.isArchived = isArchived
        self.mongoId = withUnsafeBytes(of: UUID().uuid) { $0.prefix(12).map { String(format: "%02x", $0) }.joined() }
    }
}
