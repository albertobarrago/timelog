import SwiftData
import SwiftUI

@Model
public final class Client {
    public var name: String
    public var colorHex: String
    public var isArchived: Bool
    public var mongoId: String?
    @Relationship(deleteRule: .cascade) public var projects: [Project] = []
    public var deletedAt: Date? = nil

    public init(name: String, colorHex: String = "#007AFF", isArchived: Bool = false) {
        self.name = name
        self.colorHex = colorHex
        self.isArchived = isArchived
        self.mongoId = Self.newMongoId()
    }

    public static func newMongoId() -> String {
        withUnsafeBytes(of: UUID().uuid) { $0.prefix(12).map { String(format: "%02x", $0) }.joined() }
    }

    public var color: Color { Color(hex: colorHex) ?? .accentColor }
}
