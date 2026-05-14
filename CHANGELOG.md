# Changelog

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.1.0] — 2026-05-14 (Beta)

### Added
- **iOS sync via middleware** — `RestSyncService` su `URLSession` puro (zero dipendenze SPM): pull all'avvio, push debounced su ogni modifica. Credenziali caricate automaticamente da `SyncConfig.local` nel bundle (gitignored).
- **Server middleware** (`server/`) — due endpoint Vercel TypeScript: `GET /api/pull` e `POST /api/sync`, auth via `X-API-Key`, home con Swagger UI dark su `https://timelog-server.vercel.app`.
- **Splash screen iOS** — schermata di avvio minimal dark, orologio + "Timelog" + "Track your time.", animazione fade+scale in 1.5s.
- `docs/SETUP_SYNC_SERVER.md` — guida per configurare il sync su un nuovo Mac o device.

### Fixed
- Widget extension deployment target: 16.6 → 17.0 (allineato a `TimelogCore` iOS 17+).
- `ControlWidget` marcato `@available(iOS 18.0, *)` — compila su iOS 17.
- `@main struct TimelogApp` ripristinato dopo rimozione accidentale.
- `pullAll` usa delete per-oggetto invece di batch delete — `@Query` SwiftData ora si aggiorna correttamente dopo il pull.
- Relazioni `Project.client` e `client.projects` settate da entrambi i lati — i progetti appaiono correttamente sotto il loro cliente.
- `DNSClient` / MongoKitten escluso dal target iOS (`condition: .when(platforms: [.macOS])`) — fix build iOS.

### Changed
- iOS Settings: rimossi campi URL e API Key — un solo tasto **Sync Now** + status row.
- `MongoSyncService` rimane macOS-only; iOS usa `RestSyncService` via middleware.

---

## [Unreleased]

### Added
- `MongoSyncService.pullAll(into:)` — pull sync from MongoDB → SwiftData on startup; upserts clients, projects and time entries by `mongoId`; enables multi-device and multi-user support (iOS stub is a no-op)
- In-app toast banner shown when sync (pull or push) completes successfully
- `MongoSyncService.loadConnectionStringFromFile()` — reads `~/.config/timelog/mongo.local` at startup and saves to Keychain if empty; file is never committed (outside the repo)
- `docs/` folder with technical documentation and Mermaid diagrams: architecture, data model, user flows, MongoDB sync flow

### Fixed
- `MongoSyncService`: `'Project'` type ambiguity resolved by qualifying as `TimelogCore.Project` — MongoKitten exports its own `Project` type for aggregation pipeline stages, causing the collision after Xcode 26 upgrade
- MongoDB sync now captures `modelContainer` (via `@Environment(\.modelContainer)`) instead of `modelContext` in the `dataProvider` closure — prevents stale context from returning empty fetch results

### Changed
- macOS Settings: removed MongoDB connection string text field and "Save & Sync" button — connection string is now managed exclusively via `~/.config/timelog/mongo.local` + Keychain; a "Sync Now" button and sync status remain

---

### Fixed
- iOS + macOS: project form sheet closing abruptly on save — `dismiss()` now called before `context.insert()` to prevent SwiftData relationship update from resetting the `showingAddProject` state mid-dismissal
- macOS: duplicate `client.projects.append(p)` in `ProjectMacFormView.save()` removed — SwiftData already handles the inverse relationship when setting `p.client`
- iOS: second client not saving — consolidated two `.sheet` modifiers into a single `ClientSheet` enum to fix iOS sheet reuse bug
- macOS: `Fatal error: model instance was invalidated` crash on client delete — selection now uses `PersistentIdentifier` instead of a direct `Client` reference
- macOS: `client.projects` relationship access replaced with `@Query` in `ProjectsMacView` to avoid accessing invalidated SwiftData backing
- macOS: large empty space at top of Projects view — replaced `VStack` root with `List` (same fix applied to History view)

### Added
- macOS History sidebar view: weekly bar chart (7-day, proportional bars, click to navigate) + entries grouped by client with subtotals
- iOS History sheet: date picker, per-day total, swipe-to-delete, tap-to-edit entries
- `WidgetSnapshotStore` in `TimelogCore` — writes a `TimelogWidgetSnapshot` to an App Group `UserDefaults` so the widget reads live data
- Timelog Today home-screen widget (replaces Xcode template): shows logged + active minutes, last client/project, recording indicator

### Changed
- macOS: duration input replaced with `DurationPickerMac` — 6 quick-pick buttons (15m, 30m, 45m, 1h, 1h30m, 2h) + direct text input with stepper for fine adjustment; used in QuickLog, StopSession, and History edit sheet
- iOS + macOS: client color picker replaced with a 12-swatch preset grid; native `ColorPicker` kept as "Custom" fallback — faster to use and works on all screen sizes
- `HomeView` refactored to a single `activeSheet` enum — replaces four separate `@State` booleans
- `HomeView` pushes a widget snapshot on appear and on every data change via `widgetSnapshotSignature`
- `AppTab` enum extracted to `ToolbarOnlyNavigation.swift`
- macOS sidebar now includes History between Today and Clients

### Removed
- Menu-bar-only mode (hide Dock icon toggle) — removed pending a stable implementation

---

## [0.2.0] — 2026-05-10

### Added
- Native macOS app (`TimelogMac`) with `MenuBarExtra` status bar icon
- `TimelogCore` local Swift Package — shared models, stores, VM, helpers, extensions (public API, iOS 17+ / macOS 14+)
- macOS main window: `NavigationSplitView` with Today, Clients, Timer, Settings sidebar
- macOS Today view: live active sessions, today entries, context menus, toolbar actions
- macOS Clients view: `HSplitView` clients → projects with macOS `Table`, inline create/edit sheets
- macOS Timer view: full Pomodoro / stopwatch with ring, Space shortcut
- macOS menu bar popover: compact timer controls, active sessions, today total, open-window button
- macOS Settings view: Pomodoro config, daily reminders, end-of-day threshold (`⌘,`)
- Single shared `ModelContainer` across all macOS scenes (menu bar + window see the same data)
- `MenuBarStatusLabel` extracted as a dedicated `View` struct for correct `@Observable` reactivity
- `CLAUDE.md` project context file for AI-assisted development sessions

### Changed
- **Monorepo**: `TimelogMac.xcodeproj` moved into the `TimeLog` repo alongside `Timelog.xcodeproj`
- iOS app no longer uses Mac Catalyst — pure iOS target, `#if targetEnvironment(macCatalyst)` guards removed
- All shared types migrated from inline iOS files to `TimelogCore` package (public access throughout)
- `TimerViewModel.start()` uses `RunLoop.main.add(timer, forMode: .common)` — timer no longer pauses during scroll
- `TimerView` ring frame moved onto `TimerRingView` itself — stopwatch mode no longer wastes vertical space
- `SettingsStore` properties auto-save via `didSet` — views no longer call `save()` manually
- `SettingsStore.load()` skips writes during startup via `isLoading` flag
- Removed placeholder Wethod API integration (URL + key fields) — `KeychainHelper` stays for future use

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

#### Onboarding
- 5-page first-run guide (Welcome → Manual Log → Smart Tracking → Reminders → Ready)
- Skippable at any time; re-openable from Settings → "Show guide again"
- Page-style `TabView` with dot indicators

### Changed
- Tab order: Today → Clients → Timer → Settings
- `TimerViewModel` hoisted to app-level `@Observable` environment
- Pomodoro settings in Settings immediately apply to the running `TimerViewModel`
- `ClientsView`: archived clients hidden by default; toolbar toggle to show/hide
- `QuickLogSheet`: `DatePicker` clamped to `...Date()` — no future entries
- `Project` delete rule changed from `.cascade` to `.nullify` — time entries survive project deletion
- `SettingsStore` midnight-safe load: uses `defaults.object != nil` check instead of `> 0`
- `KeychainHelper` returns `@discardableResult Bool`
- `Color+Hex.hex`: uses `resolvedColor(with:)` for reliable sRGB conversion
- `ActiveSession.elapsedMinutes` floor changed to `max(0,…)`
- Danger Zone deletes active sessions and cancels their notifications
- Day picker labels fixed: Tu / Th

### Fixed
- `Color+Hex.swift`: `NSColor(SwiftUI.Color)` unavailable on Mac Catalyst — guarded
- Widget extension: `platformFilter = ios` prevents Catalyst embed error
- App icon: added `AppIcon-512.png` (512×512) for macOS 1× slot
- `StopSessionSheet` minutes Picker replaced with Stepper — no mismatch on non-multiples-of-5 values
- `Timer` RunLoop mode changed to `.common` — no longer pauses during `List` scroll

---

## [0.0.1] — 2026-05-10

### Added
- Initial iOS app (iPhone + iPad)
- Today tab: daily time log with quick entry sheet, swipe-to-delete
- Timer tab: stopwatch mode and Pomodoro timer with animated ring progress
- Clients tab: client management with color coding, project sub-list, archive support
- Settings tab: Pomodoro intervals, weekly email export
- SwiftData persistence for `Client`, `Project`, `TimeEntry`
- `@Observable` MVVM architecture
