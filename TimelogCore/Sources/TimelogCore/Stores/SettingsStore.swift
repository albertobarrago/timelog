import Foundation
import Observation

@Observable
public final class SettingsStore {
    public var wethodBaseURL: String = ""
    public var pomodoroWork: Int = 25
    public var pomodoroShortBreak: Int = 5
    public var pomodoroLongBreak: Int = 15

    public var reminderEnabled: Bool = false
    public var reminderHour: Int = 17
    public var reminderMinute: Int = 0
    public var reminderDays: Set<Int> = [2, 3, 4, 5, 6]

    public var trackingEndHour: Int = 18
    public var trackingEndMinute: Int = 0

    private let defaults = UserDefaults.standard

    public init() { load() }

    public var wethodAPIKey: String {
        get { KeychainHelper.read(key: "wethod_api_key") ?? "" }
        set { KeychainHelper.save(key: "wethod_api_key", value: newValue) }
    }

    public func load() {
        wethodBaseURL = defaults.string(forKey: "wethod_url") ?? ""
        let w = defaults.integer(forKey: "pomodoro_work")
        let s = defaults.integer(forKey: "pomodoro_short")
        let l = defaults.integer(forKey: "pomodoro_long")
        pomodoroWork = w > 0 ? w : 25
        pomodoroShortBreak = s > 0 ? s : 5
        pomodoroLongBreak = l > 0 ? l : 15
        reminderEnabled = defaults.bool(forKey: "reminder_enabled")
        reminderHour   = defaults.object(forKey: "reminder_hour")   != nil ? defaults.integer(forKey: "reminder_hour")   : 17
        reminderMinute = defaults.object(forKey: "reminder_minute") != nil ? defaults.integer(forKey: "reminder_minute") : 0
        if let days = defaults.array(forKey: "reminder_days") as? [Int], !days.isEmpty {
            reminderDays = Set(days)
        }
        trackingEndHour   = defaults.object(forKey: "tracking_end_hour")   != nil ? defaults.integer(forKey: "tracking_end_hour")   : 18
        trackingEndMinute = defaults.object(forKey: "tracking_end_minute") != nil ? defaults.integer(forKey: "tracking_end_minute") : 0
    }

    public func save() {
        defaults.set(wethodBaseURL,      forKey: "wethod_url")
        defaults.set(pomodoroWork,       forKey: "pomodoro_work")
        defaults.set(pomodoroShortBreak, forKey: "pomodoro_short")
        defaults.set(pomodoroLongBreak,  forKey: "pomodoro_long")
        defaults.set(reminderEnabled,    forKey: "reminder_enabled")
        defaults.set(reminderHour,       forKey: "reminder_hour")
        defaults.set(reminderMinute,     forKey: "reminder_minute")
        defaults.set(Array(reminderDays),forKey: "reminder_days")
        defaults.set(trackingEndHour,    forKey: "tracking_end_hour")
        defaults.set(trackingEndMinute,  forKey: "tracking_end_minute")
    }

    public func applyReminders() {
        if reminderEnabled {
            NotificationManager.shared.reschedule(hour: reminderHour, minute: reminderMinute, days: reminderDays)
        } else {
            NotificationManager.shared.cancelAllReminders()
        }
    }
}
