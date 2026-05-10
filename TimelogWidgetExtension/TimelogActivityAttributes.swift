import ActivityKit

struct TimelogActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var displayTime: String
        var isRunning: Bool
        var phase: String
    }
}
