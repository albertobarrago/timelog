# Architettura

## Struttura Monorepo

Il repository contiene due app native e un package Swift condiviso.

```
TimeLog/
├── TimeLog.xcworkspace          ← punto di ingresso Xcode
├── Timelog.xcodeproj            ← app iOS
├── TimelogMac.xcodeproj         ← app macOS
├── TimelogCore/                 ← Swift Package condiviso
│   └── Sources/
│       ├── TimelogCore/         ← modelli, VM, stores, helpers
│       └── TimelogSync/         ← integrazione MongoDB (macOS)
├── Timelog/                     ← Views iOS
├── TimelogMac/                  ← Views macOS
└── TimelogWidgetExtension/      ← Widget + Live Activity (iOS)
```

## Layer dell'applicazione

```mermaid
graph TD
    subgraph iOS["App iOS (Timelog)"]
        iViews["Views iOS<br/>SwiftUI"]
    end

    subgraph macOS["App macOS (TimelogMac)"]
        mViews["Views macOS<br/>SwiftUI"]
        mMenu["MenuBarExtra"]
    end

    subgraph Widget["Widget Extension"]
        wWidget["Widget Today<br/>Live Activity"]
    end

    subgraph Core["TimelogCore (Swift Package)"]
        Models["Models<br/>Client · Project<br/>TimeEntry · ActiveSession"]
        VM["TimerViewModel"]
        Store["SettingsStore<br/>WidgetSnapshotStore"]
        Helpers["KeychainHelper<br/>NotificationManager"]
        Ext["Extensions<br/>Color+Hex · Int+Duration"]
    end

    subgraph Sync["TimelogSync (Swift Package)"]
        MongoSvc["MongoSyncService<br/>(macOS full · iOS stub)"]
    end

    subgraph Infra["Infrastruttura"]
        SD[("SwiftData<br/>SQLite locale")]
        KCH[("Keychain")]
        UNS["UNUserNotificationCenter"]
        MDB[("MongoDB Atlas")]
        AG["App Group<br/>group.me.albz.timelog"]
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

    MongoSvc --> KCH
    MongoSvc -->|"macOS only"| MDB
```

## Regole architetturali

| Regola | Motivazione |
|--------|-------------|
| Business logic solo in `TimelogCore` | Le app contengono esclusivamente Views |
| Tutto `public` in TimelogCore | Visibile da entrambe le app e dalla widget |
| Un solo `ModelContainer` per app | Evita conflitti SwiftData; in macOS è `static let` condiviso tra WindowGroup e MenuBarExtra |
| `TimelogSync` dipende da MongoKitten **solo su macOS** | Riduce il binary size iOS; su iOS MongoSyncService è uno stub no-op |
| `#if os(iOS)` per ActivityKit e UIKit haptics | Non usare `#if targetEnvironment(macCatalyst)` — il progetto non usa Catalyst |

## Dipendenze Package

```mermaid
graph LR
    TimelogCore["TimelogCore"]
    TimelogSync["TimelogSync"]
    MongoKitten["MongoKitten 7.9.0+<br/>(solo macOS)"]

    TimelogSync --> TimelogCore
    TimelogSync -->|"#if os(macOS)"| MongoKitten
```

## Entry point per piattaforma

### iOS — `TimelogApp.swift`
```
App
 └─ ModelContainer (Client, Project, TimeEntry, ActiveSession)
     └─ ContentView
         ├─ TabBar: Today · Clients · Timer · Settings
         └─ MongoSyncSetup (modifier — stub)
```

### macOS — `TimelogMacApp.swift`
```
App
 ├─ static ModelContainer (condiviso)
 ├─ WindowGroup "main"
 │   └─ MainMacView
 │       ├─ NavigationSplitView: Today · Clients · Tracking · Settings
 │       └─ MongoSyncSetup (modifier — connette e avvia auto-sync)
 ├─ MenuBarExtra
 │   └─ MenuBarView (window style)
 └─ Settings (⌘,)
     └─ MacSettingsView
```
