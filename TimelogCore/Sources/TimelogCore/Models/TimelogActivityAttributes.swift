#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit

public struct TimelogActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var displayTime: String
        public var isRunning: Bool
        public var phase: String

        public init(displayTime: String, isRunning: Bool, phase: String) {
            self.displayTime = displayTime
            self.isRunning = isRunning
            self.phase = phase
        }
    }

    public init() {}
}
#endif
