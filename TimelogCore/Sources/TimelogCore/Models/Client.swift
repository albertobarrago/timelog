import SwiftData
import SwiftUI

@Model
public final class Client {
    public var name: String
    public var colorHex: String
    public var isArchived: Bool
    @Relationship(deleteRule: .cascade) public var projects: [Project] = []

    public init(name: String, colorHex: String = "#007AFF", isArchived: Bool = false) {
        self.name = name
        self.colorHex = colorHex
        self.isArchived = isArchived
    }

    public var color: Color { Color(hex: colorHex) ?? .accentColor }
}
