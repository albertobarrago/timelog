import Testing
import Foundation
@testable import TimelogCore

@Suite("SettingsStore")
struct SettingsStoreTests {

    private func makeStore() -> (store: SettingsStore, suiteName: String) {
        let suiteName = "test_timelog_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (SettingsStore(defaults: defaults), suiteName)
    }

    @Test func defaultPomodoroValues() {
        let (store, suite) = makeStore()
        #expect(store.pomodoroWork == 25)
        #expect(store.pomodoroShortBreak == 5)
        #expect(store.pomodoroLongBreak == 15)
        UserDefaults().removePersistentDomain(forName: suite)
    }

    @Test func defaultReminderValues() {
        let (store, suite) = makeStore()
        #expect(store.reminderEnabled == false)
        #expect(store.reminderHour == 17)
        #expect(store.reminderMinute == 0)
        #expect(store.reminderDays == [2, 3, 4, 5, 6])
        UserDefaults().removePersistentDomain(forName: suite)
    }

    @Test func defaultTrackingEndValues() {
        let (store, suite) = makeStore()
        #expect(store.trackingEndHour == 18)
        #expect(store.trackingEndMinute == 0)
        UserDefaults().removePersistentDomain(forName: suite)
    }

    @Test func saveAndLoadPomodoroWork() {
        let suiteName = "test_timelog_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.pomodoroWork = 45
        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.pomodoroWork == 45)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func saveAndLoadReminderDays() {
        let suiteName = "test_timelog_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.reminderDays = [2, 4, 6]
        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.reminderDays == [2, 4, 6])
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func saveAndLoadTrackingEnd() {
        let suiteName = "test_timelog_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.trackingEndHour = 19
        store1.trackingEndMinute = 30
        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.trackingEndHour == 19)
        #expect(store2.trackingEndMinute == 30)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
