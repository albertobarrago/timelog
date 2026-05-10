# Timelog

A lightweight time-tracking app for iOS and macOS built with SwiftUI and SwiftData.

## Features

| Tab | Description |
|-----|-------------|
| **Today** | Log time entries, see daily total, swipe to delete |
| **Timer** | Stopwatch mode or Pomodoro timer with ring progress |
| **Clients** | Manage clients (with color coding) and their projects |
| **Settings** | Wethod API integration, Pomodoro intervals, weekly email export |

## Requirements

- Xcode 15+
- iOS 17+ / macOS 14+
- No external dependencies — pure Swift ecosystem (SwiftData, Keychain)

## Getting Started

```bash
git clone <repo-url>
open Timelog.xcodeproj
```

Select your target (iOS or macOS), then **Run** (`⌘R`).

No setup required for basic use. To enable Wethod integration, add your Base URL and API Key in **Settings** — the key is stored securely in the Keychain.

## Project Structure

```
Timelog/
├── Models/          # SwiftData models (Client, Project, TimeEntry)
├── ViewModels/      # TimerViewModel (@Observable)
├── Stores/          # SettingsStore — UserDefaults + Keychain
├── Views/
│   ├── Home/        # Daily log + QuickLogSheet
│   ├── Timer/       # Stopwatch / Pomodoro
│   ├── Clients/     # Client & project management
│   └── Settings/    # Config + export
├── Extensions/      # Color+Hex, Int+Duration
└── Helpers/         # KeychainHelper
```

## Architecture

- **MVVM** with SwiftUI's `@Observable` macro
- **SwiftData** for local persistence
- **Keychain** for the Wethod API key (never stored in UserDefaults)

## Contributing

1. Branch off `main`
2. Keep one feature per PR
3. Run the existing UI tests before opening a PR (`⌘U`)
