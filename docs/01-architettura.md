# Architecture

## Monorepo Structure

The repository contains two native apps and a shared Swift package.

```
TimeLog/
├── TimeLog.xcworkspace          ← Xcode entry point
├── Timelog.xcodeproj            ← iOS app
├── TimelogMac.xcodeproj         ← macOS app
├── TimelogCore/                 ← shared Swift Package
│   └── Sources/
│       ├── TimelogCore/         ← models, VM, stores, helpers
│       └── TimelogSync/         ← MongoSyncService (macOS) + RestSyncService (iOS)
├── Timelog/                     ← iOS Views
├── TimelogMac/                  ← macOS Views
├── TimelogWidgetExtension/      ← Widget + Live Activity (iOS)
└── server/                      ← Vercel middleware (Node.js/TypeScript)
    └── api/
        ├── pull.ts              ← GET  /api/pull
        └── sync.ts              ← POST /api/sync
```

## Application Layers

```mermaid
graph TD
    subgraph iOS["iOS App (Timelog)"]
        iViews["iOS Views\nSwiftUI"]
        iSplash["SplashView"]
    end

    subgraph macOS["macOS App (TimelogMac)"]
        mViews["macOS Views\nSwiftUI"]
        mMenu["MenuBarExtra"]
    end

    subgraph Widget["Widget Extension"]
        wWidget["Today Widget\nLive Activity"]
    end

    subgraph Core["TimelogCore (Swift Package)"]
        Models["Models\nClient · Project\nTimeEntry · ActiveSession"]
        VM["TimerViewModel"]
        Store["SettingsStore\nWidgetSnapshotStore"]
        Helpers["KeychainHelper\nNotificationManager"]
        Ext["Extensions\nColor+Hex · Int+Duration"]
    end

    subgraph Sync["TimelogSync (Swift Package)"]
        RestSvc["RestSyncService\n(iOS — URLSession → Vercel)"]
        MongoSvc["MongoSyncService\n(macOS — MongoKitten → Atlas)"]
    end

    subgraph Infra["Infrastructure"]
        SD[("SwiftData\nlocal SQLite")]
        KCH[("Keychain")]
        UNS["UNUserNotificationCenter"]
        MDB[("MongoDB Atlas")]
        VCL["Vercel Functions\nGET /api/pull · POST /api/sync"]
        AG["App Group\ngroup.me.albz.timelog"]
    end

    iViews --> Core
    iViews --> Sync
    mViews --> Core
    mViews --> Sync
    mMenu --> Core
    Widget --> Core

    VM --> UNS
    VM -.->|"iOS only"| LiveActivity["ActivityKit\nLive Activity"]
    Store --> UNS
    Helpers --> KCH
    Models --> SD
    Store --> AG
    Widget --> AG

    RestSvc --> KCH
    RestSvc -->|"iOS only"| VCL
    VCL -->|"upsert"| MDB

    MongoSvc --> KCH
    MongoSvc -->|"macOS only"| MDB
```

## Architectural Rules

| Rule | Rationale |
|------|-----------|
| Business logic only in `TimelogCore` | Apps contain exclusively Views |
| Everything `public` in TimelogCore | Visible from both apps and the widget |
| One `ModelContainer` per app | Avoids SwiftData conflicts; on macOS it is `static let` shared between WindowGroup and MenuBarExtra |
| iOS uses `RestSyncService`, macOS uses `MongoSyncService` | iOS cannot use MongoKitten (ARM-only binary, heavy dependencies); the same public signature separates the implementations |
| `#if os(iOS)` for ActivityKit and UIKit haptics | Do not use `#if targetEnvironment(macCatalyst)` — the project does not use Catalyst |
| `deletedAt: Date?` on Client, Project, TimeEntry | Soft delete: deleted records are marked but not removed from the database until sync has propagated them to all devices. `ActiveSession` has no `deletedAt` because it is always converted to a `TimeEntry` on stop. |

## Package Dependencies

```mermaid
graph LR
    TimelogCore["TimelogCore"]
    TimelogSync["TimelogSync"]
    MongoKitten["MongoKitten 7.9.0+\n(macOS only)"]

    TimelogSync --> TimelogCore
    TimelogSync -->|"#if os(macOS)"| MongoKitten
```

## Entry Points by Platform

### iOS — `TimelogApp.swift`
```
App
 └─ ModelContainer (Client, Project, TimeEntry, ActiveSession)
     └─ ZStack
         ├─ ContentView
         │   ├─ TabBar: Today · Clients · Timer · Settings
         │   ├─ RestSyncSetup (modifier — pull on launch, push debounced 2s)
         │   └─ SyncFlashOverlay (modifier — green flash + haptic on sync)
         └─ SplashView (fades after initial animation)
```

### macOS — `TimelogMacApp.swift`
```
App
 ├─ static ModelContainer (shared)
 ├─ WindowGroup "main"
 │   └─ MainMacView
 │       ├─ NavigationSplitView: Today · Clients · Tracking · Settings
 │       └─ MongoSyncSetup (modifier — connects and starts auto-sync)
 ├─ MenuBarExtra
 │   └─ MenuBarView (window style)
 │       └─ MenuBarStatusLabel (shows timer if running)
 └─ Settings (⌘,)
     └─ MacSettingsView
```
