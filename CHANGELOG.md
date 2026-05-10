# Changelog

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [0.1.0] — 2026-05-10

### Added

#### Smart Tracking
- Real-time session tracker: start a session per project, stop it to auto-log a `TimeEntry`
- Multiple concurrent sessions supported
- Sessions survive app kill (elapsed computed from `startDate`, no Timer on the model)
- `ActiveSession` SwiftData model with live `hh:mm:ss` display via `TimelineView`
- Start Tracking sheet — pick client/project/notes, tap Start
- Stop Tracking sheet — pre-filled elapsed duration via Steppers (hours 0–23, minutes 0–59), fully editable
- Swipe-to-discard on active sessions (cancels notification, no entry logged)
- Today total card now includes running session time and ticks live every minute
- Today card icon switches to red `record.circle.fill` when a session is active

#### Reminders & Notifications
- Daily reminder: configurable time + day-of-week picker (M Tu W Th F Sa Su)
- Smart Tracking overdue alert: fires at configurable end-of-day if a session is still open
- Pomodoro phase-end notification when the screen is locked
- `NotificationManager` with separate `cancelAllReminders()` / `cancelAllSessions()` / `cancelPomodoroNotification()`

#### Haptics
- `.medium` impact on timer start
- `.light` impact on timer pause
- `.rigid` impact on timer reset
- `.success` notification feedback on session log

#### iOS Live Activity
- Lock screen banner and Dynamic Island showing timer phase, display time, and running state
- Updates every 5 seconds; ends on reset
- `NSSupportsLiveActivities` + `NSSupportsLiveActivitiesFrequentUpdates` in `Info.plist`
- Widget Extension (`TimelogWidgetExtensionExtension`) with `DynamicIsland` support

#### Mac Catalyst
- Persistent toolbar button across all tabs showing live elapsed time
- Clicking navigates to Timer tab; if already there, toggles start/pause

#### Onboarding
- 5-page first-run guide (Welcome → Manual Log → Smart Tracking → Reminders → Ready)
- Skippable at any time; re-openable from Settings → "Show guide again"
- Page-style `TabView` with dot indicators (iOS) / plain tabs (macOS)

### Changed
- Tab order: Today → Clients → Timer → Settings (all platforms)
- `TimerViewModel` hoisted to app-level `@Observable` environment
- `Timer` now added to `.common` RunLoop mode — no longer pauses during List scroll
- Pomodoro settings in Settings immediately apply to the running `TimerViewModel`
- `ClientsView`: archived clients hidden by default; toolbar toggle to show/hide
- `QuickLogSheet`: `DatePicker` clamped to `...Date()` — no future entries
- `Project` delete rule changed from `.cascade` to `.nullify` — time entries survive project deletion
- `SettingsStore` midnight-safe load: uses `defaults.object != nil` check instead of `> 0`
- `KeychainHelper` functions now return `@discardableResult Bool`
- `Color+Hex.hex`: uses `resolvedColor(with:)` for reliable sRGB conversion on all platforms
- `ActiveSession.elapsedMinutes` floor changed from `max(1,…)` to `max(0,…)`
- Danger Zone now also deletes active sessions and cancels their notifications
- Day picker labels fixed: Tu / Th (previously both showed "T")

### Fixed
- `Color+Hex.swift`: `NSColor(SwiftUI.Color)` crash on Mac Catalyst — guarded with `!targetEnvironment(macCatalyst)`
- Widget extension platform filter: `platformFilter = ios` prevents Catalyst embed error
- App icon: added `AppIcon-512.png` (512×512) for macOS 1× slot

---

## [0.0.1] — 2026-05-10

### Added
- Initial multiplatform app (iOS 17+ / macOS 14+)
- Today tab: daily time log with quick entry sheet, swipe-to-delete
- Timer tab: stopwatch mode and Pomodoro timer with animated ring progress
- Clients tab: client management with color coding, project sub-list, archive support
- Settings tab: Wethod API config (URL + Keychain-stored key), Pomodoro intervals, weekly email export
- SwiftData persistence for `Client`, `Project`, `TimeEntry`
- `@Observable` MVVM architecture
