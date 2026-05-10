import SwiftUI
import TimelogCore

struct MacSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(TimerViewModel.self) private var timerVM

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Wethod API") {
                TextField("Base URL", text: $store.wethodBaseURL)
                    .onChange(of: store.wethodBaseURL) { store.save() }
            }

            Section("Pomodoro") {
                Stepper("Focus: \(store.pomodoroWork) min", value: $store.pomodoroWork, in: 1...90)
                    .onChange(of: store.pomodoroWork) { store.save(); timerVM.applySettings(store) }
                Stepper("Short break: \(store.pomodoroShortBreak) min", value: $store.pomodoroShortBreak, in: 1...30)
                    .onChange(of: store.pomodoroShortBreak) { store.save(); timerVM.applySettings(store) }
                Stepper("Long break: \(store.pomodoroLongBreak) min", value: $store.pomodoroLongBreak, in: 1...60)
                    .onChange(of: store.pomodoroLongBreak) { store.save(); timerVM.applySettings(store) }
            }

            Section("Smart Tracking") {
                DatePicker("Notify if still open at",
                           selection: trackingEndTime,
                           displayedComponents: .hourAndMinute)
                    .onChange(of: store.trackingEndHour) { store.save() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 300)
    }

    private var trackingEndTime: Binding<Date> {
        Binding(
            get: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                c.hour = store.trackingEndHour; c.minute = store.trackingEndMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.trackingEndHour = c.hour ?? 18
                store.trackingEndMinute = c.minute ?? 0
                store.save()
            }
        )
    }
}
