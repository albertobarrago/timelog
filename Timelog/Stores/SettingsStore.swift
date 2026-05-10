import Foundation
import Observation

@Observable
final class SettingsStore {
    var wethodBaseURL: String = ""
    var pomodoroWork: Int = 25
    var pomodoroShortBreak: Int = 5
    var pomodoroLongBreak: Int = 15

    var reminderEnabled: Bool = false
    var reminderHour: Int = 17
    var reminderMinute: Int = 0
    var reminderDays: Set<Int> = [2, 3, 4, 5, 6] // Mon–Fri (Calendar: 1=Sun … 7=Sat)

    var trackingEndHour: Int = 18
    var trackingEndMinute: Int = 0

    private let defaults = UserDefaults.standard

    init() { load() }

    var wethodAPIKey: String {
        get { KeychainHelper.read(key: "wethod_api_key") ?? "" }
        set { KeychainHelper.save(key: "wethod_api_key", value: newValue) }
    }

    func load() {
        wethodBaseURL = defaults.string(forKey: "wethod_url") ?? ""
        let w = defaults.integer(forKey: "pomodoro_work")
        let s = defaults.integer(forKey: "pomodoro_short")
        let l = defaults.integer(forKey: "pomodoro_long")
        pomodoroWork = w > 0 ? w : 25
        pomodoroShortBreak = s > 0 ? s : 5
        pomodoroLongBreak = l > 0 ? l : 15

        reminderEnabled = defaults.bool(forKey: "reminder_enabled")
        let rh = defaults.integer(forKey: "reminder_hour")
        reminderHour = rh > 0 ? rh : 17
        reminderMinute = defaults.integer(forKey: "reminder_minute")
        if let days = defaults.array(forKey: "reminder_days") as? [Int], !days.isEmpty {
            reminderDays = Set(days)
        }

        let th = defaults.integer(forKey: "tracking_end_hour")
        trackingEndHour = th > 0 ? th : 18
        trackingEndMinute = defaults.integer(forKey: "tracking_end_minute")
    }

    func save() {
        defaults.set(wethodBaseURL, forKey: "wethod_url")
        defaults.set(pomodoroWork, forKey: "pomodoro_work")
        defaults.set(pomodoroShortBreak, forKey: "pomodoro_short")
        defaults.set(pomodoroLongBreak, forKey: "pomodoro_long")
        defaults.set(reminderEnabled, forKey: "reminder_enabled")
        defaults.set(reminderHour, forKey: "reminder_hour")
        defaults.set(reminderMinute, forKey: "reminder_minute")
        defaults.set(Array(reminderDays), forKey: "reminder_days")
        defaults.set(trackingEndHour, forKey: "tracking_end_hour")
        defaults.set(trackingEndMinute, forKey: "tracking_end_minute")
    }

    func applyReminders() {
        if reminderEnabled {
            NotificationManager.shared.reschedule(hour: reminderHour, minute: reminderMinute, days: reminderDays)
        } else {
            NotificationManager.shared.cancelAll()
        }
    }
}
