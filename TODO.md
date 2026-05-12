# TODO — Improvement Backlog

## 🧭 Product / Strategy

- [ ] **Centralized MongoDB sync** — add a backend-backed data layer so iOS and macOS share the same clients, projects, time entries, and active sessions. First target: personal work use across mobile/desktop. Secondary target: showcase a senior-level, production-minded architecture with clean API boundaries, sync/conflict strategy, auth, observability, tests, and deployment discipline.

## 🔴 Bug / Logic

- [x] **Today total ignores active sessions** — `HomeView` now adds `activeSessions.reduce(0) { $0 + $1.elapsedMinutes }` to the total; card wrapped in `TimelineView(.periodic(by: 60))` so it ticks live. Icon switches to `record.circle.fill` (red) when sessions are active.
- [x] **StopSessionSheet minutes picker mismatch** — replaced pair of Pickers with two Steppers (hours 0–23, minutes 0–59), so any elapsed value pre-fills correctly.
- [x] **Timer pauses during scroll** — `TimerViewModel.start()` now uses `RunLoop.main.add(timer, forMode: .common)` instead of `scheduledTimer`.
- [x] **DayPicker duplicate "T"** — labels changed to M / Tu / W / Th / F / Sa / Su.
- [x] **SettingsStore midnight reminder bug** — `reminderHour` and `trackingEndHour` now use `defaults.object(forKey:) != nil` to distinguish "not set" from "set to 0", so midnight reminders survive a relaunch.
- [x] **NotificationManager.cancelAll() leaves session notifications** — renamed to `cancelAllReminders()` (reminders only); added `cancelAllSessions()` (async fetch + remove `session_*`); Danger Zone now calls both + deletes `ActiveSession` records.
- [x] **Project cascade delete removes TimeEntries** — changed to `.nullify` so entries survive with `project = nil`.

## 🟡 UX

- [x] **Pomodoro phase complete: no notification when locked** — `NotificationManager.schedulePomodoroEnd(phase:in:)` fires a `UNTimeIntervalNotificationTrigger` when a phase starts; cancelled on pause/reset.
- [x] **No haptic feedback** — `TimerViewModel`: `.medium` on start, `.light` on pause, `.rigid` on reset. `StopSessionSheet`: `.success` notification haptic on log.
- [x] **QuickLogSheet allows future dates** — `DatePicker` clamped to `in: ...Date()`.
- [x] **Archived clients always visible** — `ClientsView` now has a toolbar toggle (archivebox icon) to show/hide archived clients; hidden by default.
- [ ] **Menu-bar-only macOS mode** — hide Dock icon, keep app accessible from menu bar only. Removed pending a stable macOS 26 implementation (window state restoration causes duplicate windows).
- [x] **No history view** — iOS `HomeView` opens a History sheet; macOS has a sidebar History view. Both provide date picker, per-day total, editable entries, and delete actions.
- [ ] **No deep link from session overdue notification** — URL scheme + `onOpenURL` handler needed to jump directly to active sessions.
- [x] **Widget home-screen widget shows Xcode template** — replaced with a real "Timelog Today" widget backed by an App Group snapshot; removed the template control widget from the bundle.

## 🟢 Code quality

- [x] **Settings not applied to TimerViewModel on change** — `SettingsView` now has `@Environment(TimerViewModel.self)` and calls `timerVM.applySettings(store)` inside each Pomodoro stepper's `onChange`.
- [x] **Color+Hex hex var: no fallback on UIColor.getRed failure** — now uses `resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))` before calling `getRed`, ensuring sRGB space.
- [x] **ActiveSession.elapsedMinutes min cap of 1** — changed to `max(0, ...)`.
- [x] **KeychainHelper errors silently discarded** — `save()` and `delete()` now return `@discardableResult Bool`.
- [x] **SettingsStore: too many individual save() calls** — auto-save via `didSet`, no explicit `save()` calls needed.
- [ ] **Missing unit tests** — `TimerViewModel`, `NotificationManager` scheduling math, `Int.formattedDuration`.
- [ ] **Missing iPad layout** — scale-up iPhone layout; could use `NavigationSplitView`.
