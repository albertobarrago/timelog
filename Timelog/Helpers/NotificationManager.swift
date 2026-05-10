import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Daily reminders

    func reschedule(hour: Int, minute: Int, days: Set<Int>) {
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
            let request = UNNotificationRequest(
                identifier: "timelog_reminder_\(weekday)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelAllReminders() {
        let ids = (1...7).map { "timelog_reminder_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Session overdue

    func scheduleSessionOverdue(id: String, clientName: String, projectName: String?,
                                startDate: Date, endHour: Int, endMinute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Did you forget to stop tracking?"
        let projectText = projectName.map { " / \($0)" } ?? ""
        let startStr = startDate.formatted(date: .omitted, time: .shortened)
        content.body = "\(clientName)\(projectText) started at \(startStr) is still running."
        content.sound = .default
        content.userInfo = ["sessionID": id]

        let calendar = Calendar.current
        var fireDate = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: startDate) ?? startDate
        if fireDate <= .now { fireDate = Date().addingTimeInterval(4 * 3600) }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "session_\(id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelSession(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["session_\(id)"])
    }

    func cancelAllSessions() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("session_") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Pomodoro phase end

    func schedulePomodoroEnd(phase: String, in seconds: TimeInterval) {
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

    func cancelPomodoroNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pomodoro_phase"])
    }
}
