# Changelog

## [Unreleased]

### Added

#### Smart Tracking (auto mode)
- New `ActiveSession` SwiftData model: start time, client, project, notes, notification ID
- Start Tracking sheet — pick client/project, tap Start; timer begins immediately
- Stop Tracking sheet — pre-filled elapsed duration (editable in 5-min steps), notes, then logs a `TimeEntry` automatically
- Multiple concurrent sessions supported
- Sessions survive app kill (elapsed computed from `startDate`, no Timer on the model)
- HomeView now shows an **Active** section at the top with a live `hh:mm:ss` ticker (`TimelineView`)
- Swipe-to-discard on active sessions (cancels notification, no entry logged)
- Two toolbar buttons in HomeView: `▶` (start tracking) and `+` (manual log)

#### Reminders (local notifications)
- Daily reminder: configurable time + days of week (circular day picker, Mon–Fri default)
- Smart Tracking overdue alert: fires at configurable end-of-day time if a session is still open
- `NotificationManager` singleton handles scheduling, rescheduling, and cancellation
- Notification permission requested on first launch

#### macOS toolbar
- Persistent toolbar button in all tabs showing elapsed time while a timer is running
- Clicking navigates to the Timer tab; if already there, toggles start/pause
- Requires Mac Catalyst destination to be enabled in Xcode

#### iOS Live Activity
- Lock screen banner and Dynamic Island show timer phase, elapsed time, and running state
- Updates every 5 seconds while running; ends when timer is reset
- `NSSupportsLiveActivities` + `NSSupportsLiveActivitiesFrequentUpdates` added to `Info.plist`
- Widget Extension target (`TimelogWidgetExtensionExtension`) with `TimelogLiveActivity` widget

#### App icon fix
- `AppIcon-512.png` (512×512) added for macOS 1× slot; original 1024×1024 retained for iOS and macOS 2×

#### Architecture
- `TimerViewModel` hoisted to app-level `@Observable` environment (shared across all tabs and the toolbar button)

### Changed
- `SettingsStore` — added `reminderEnabled`, `reminderHour`, `reminderMinute`, `reminderDays`, `trackingEndHour`, `trackingEndMinute`
- `SettingsView` — new Reminders section (toggle + time picker + day picker) and Smart Tracking section (end-of-day threshold)
- `HomeView` — refactored to show active sessions above today's entries; empty state updated
- `TimerView` — reads `TimerViewModel` from environment instead of owning it as local state
