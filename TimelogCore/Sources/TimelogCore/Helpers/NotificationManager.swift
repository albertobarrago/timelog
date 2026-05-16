import UserNotifications

public final class NotificationManager {
    public static let shared = NotificationManager()
    private static let overdueNotificationDelay: TimeInterval = 4 * 3600
    private init() {}

    public func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Daily reminders

    public func reschedule(hour: Int, minute: Int, days: Set<Int>) {
        cancelAllReminders()
        let content = UNMutableNotificationContent()
        content.title = "Time to log!"
        content.body = "Don't forget to fill in your timesheet for today."
        content.sound = .default
        for weekday in days {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.weekday = weekday
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "timelog_reminder_\(weekday)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    public func cancelAllReminders() {
        let ids = (1...7).map { "timelog_reminder_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Session overdue

    public func scheduleSessionOverdue(id: String, clientName: String, projectName: String?,
                                       startDate: Date, endHour: Int, endMinute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Did you forget to stop tracking?"
        let projectText = projectName.map { " / \($0)" } ?? ""
        content.body = "\(clientName)\(projectText) started at \(startDate.formatted(date: .omitted, time: .shortened)) is still running."
        content.sound = .default
        content.userInfo = ["sessionID": id]
        let calendar = Calendar.current
        var fireDate = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: startDate) ?? startDate
        if fireDate <= .now { fireDate = Date().addingTimeInterval(Self.overdueNotificationDelay) }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "session_\(id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    public func cancelSession(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["session_\(id)"])
    }

    public func cancelAllSessions() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix("session_") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Pomodoro

    public func schedulePomodoroEnd(phase: String, in seconds: TimeInterval) {
        cancelPomodoroNotification()
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(phase) complete!"
        content.body = phase == "Focus" ? "Time for a break." : "Back to work!"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "pomodoro_phase", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    public func cancelPomodoroNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pomodoro_phase"])
    }
}
