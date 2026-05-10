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
                SecureField("API Key", text: apiKeyBinding)
            }

            Section("Pomodoro") {
                Stepper("Focus: \(store.pomodoroWork) min",
                        value: $store.pomodoroWork, in: 1...90)
                    .onChange(of: store.pomodoroWork) { store.save(); timerVM.applySettings(store) }
                Stepper("Short break: \(store.pomodoroShortBreak) min",
                        value: $store.pomodoroShortBreak, in: 1...30)
                    .onChange(of: store.pomodoroShortBreak) { store.save(); timerVM.applySettings(store) }
                Stepper("Long break: \(store.pomodoroLongBreak) min",
                        value: $store.pomodoroLongBreak, in: 1...60)
                    .onChange(of: store.pomodoroLongBreak) { store.save(); timerVM.applySettings(store) }
            }

            Section {
                Toggle("Daily reminder", isOn: $store.reminderEnabled)
                    .onChange(of: store.reminderEnabled) { store.save(); store.applyReminders() }
                if store.reminderEnabled {
                    DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Days").font(.caption).foregroundStyle(.secondary)
                        DayPickerMac(selectedDays: $store.reminderDays)
                            .onChange(of: store.reminderDays) { store.save(); store.applyReminders() }
                    }
                }
            } header: {
                Text("Reminders")
            }

            Section {
                DatePicker("Notify if still open at",
                           selection: trackingEndTime,
                           displayedComponents: .hourAndMinute)
                    .onChange(of: store.trackingEndHour) { store.save() }
            } header: {
                Text("Smart Tracking")
            } footer: {
                Text("Sends a notification if a session is still running at this time.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(maxWidth: 520)
    }

    // MARK: - Bindings

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { store.wethodAPIKey },
            set: { store.wethodAPIKey = $0 }
        )
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
                c.hour = store.reminderHour; c.minute = store.reminderMinute
                return Calendar.current.date(from: c) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.reminderHour = c.hour ?? 17
                store.reminderMinute = c.minute ?? 0
                store.save(); store.applyReminders()
            }
        )
    }

    private var trackingEndTime: Binding<Date> {
        Binding(
            get: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
                c.hour = store.trackingEndHour; c.minute = store.trackingEndMinute
                return Calendar.current.date(from: c) ?? .now
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

private struct DayPickerMac: View {
    @Binding var selectedDays: Set<Int>

    private let days: [(label: String, index: Int)] = [
        ("M", 2), ("Tu", 3), ("W", 4), ("Th", 5), ("F", 6), ("Sa", 7), ("Su", 1)
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.index) { day in
                let on = selectedDays.contains(day.index)
                Button {
                    if on { selectedDays.remove(day.index) }
                    else  { selectedDays.insert(day.index) }
                } label: {
                    Text(day.label)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(on ? Color.accentColor : Color.secondary.opacity(0.15),
                                    in: Circle())
                        .foregroundStyle(on ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
