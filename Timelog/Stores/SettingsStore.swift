import Foundation
import Observation

@Observable
final class SettingsStore {
    var wethodBaseURL: String = ""
    var pomodoroWork: Int = 25
    var pomodoroShortBreak: Int = 5
    var pomodoroLongBreak: Int = 15

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
    }

    func save() {
        defaults.set(wethodBaseURL, forKey: "wethod_url")
        defaults.set(pomodoroWork, forKey: "pomodoro_work")
        defaults.set(pomodoroShortBreak, forKey: "pomodoro_short")
        defaults.set(pomodoroLongBreak, forKey: "pomodoro_long")
    }
}
