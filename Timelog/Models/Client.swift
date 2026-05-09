import SwiftData
import SwiftUI

@Model
final class Client {
    var name: String
    var colorHex: String
    var isArchived: Bool
    @Relationship(deleteRule: .cascade) var projects: [Project] = []

    init(name: String, colorHex: String = "#007AFF", isArchived: Bool = false) {
        self.name = name
        self.colorHex = colorHex
        self.isArchived = isArchived
    }

    var color: Color { Color(hex: colorHex) ?? .accentColor }
}
