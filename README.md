<p align="center">
  <img src="Timelog/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="Timelog icon" />
</p>

<h1 align="center">Timelog</h1>

<p align="center">
  A lightweight time-tracking app for iOS and macOS built with SwiftUI and SwiftData.
</p>

---

## Features

| Tab | Description |
|-----|-------------|
| **Today** | Log time manually, start real-time tracking sessions, see live daily total |
| **Clients** | Manage clients (color coded) and their projects; archive when done |
| **Timer** | Stopwatch or Pomodoro timer with ring progress and phase notifications |
| **Settings** | Wethod API, Pomodoro intervals, daily reminders, smart tracking config |

### Smart Tracking
Tap ▶ to start a session when you begin working — pick client and project, hit Start. Stop it when you're done and the duration is logged automatically. Multiple sessions can run simultaneously. If you forget to stop, you'll get a notification at your configured end-of-day time.

### Reminders
Set a daily nudge at a chosen time on chosen days so nobody on your team forgets to fill in their timesheet.

### iOS Live Activity
Active timer sessions appear on the lock screen and in the Dynamic Island, so you always know what's running without opening the app.

---

## Requirements

- Xcode 16+
- iOS 17+ / macOS 14+ (Mac Catalyst)
- No external dependencies — pure Swift ecosystem (SwiftData, Keychain, ActivityKit, UserNotifications)

---

## Getting Started

```bash
git clone https://github.com/AlbertoBarrago/Timelog.git
open Timelog.xcodeproj
```

Select your target (iOS or macOS), then **Run** (`⌘R`).

**Wethod integration**: add your Base URL and API Key in Settings — the key is stored securely in the Keychain.

**Live Activity**: requires a physical device; Dynamic Island requires iPhone 14 Pro or later.

---

## Project Structure

```
Timelog/
├── Models/              # SwiftData models (Client, Project, TimeEntry, ActiveSession)
├── ViewModels/          # TimerViewModel (@Observable, app-level)
├── Stores/              # SettingsStore — UserDefaults + Keychain
├── Helpers/             # KeychainHelper, NotificationManager
├── Extensions/          # Color+Hex, Int+Duration
└── Views/
    ├── Home/            # Daily log, QuickLogSheet, StartTrackingSheet, StopSessionSheet
    ├── Timer/           # Stopwatch / Pomodoro + ring view
    ├── Clients/         # Client & project management
    ├── Settings/        # Config, reminders, export
    └── Onboarding/      # First-run guide

TimelogWidgetExtension/  # Live Activity widget (lock screen + Dynamic Island)
```

---

## Architecture

- **MVVM** with SwiftUI's `@Observable` macro
- **SwiftData** for local persistence with cascade/nullify relationships
- **Keychain** for the Wethod API key
- **ActivityKit** for iOS Live Activities
- **UserNotifications** for daily reminders and smart tracking alerts

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

## Contributing

1. Branch off `main`
2. Keep one feature per PR
3. Run the existing UI tests before opening a PR (`⌘U`)
