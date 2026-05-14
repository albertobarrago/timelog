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
│       └── TimelogSync/         ← MongoSyncService (macOS) + RestSyncService (iOS)
├── Timelog/                     ← Views iOS
├── TimelogMac/                  ← Views macOS
├── TimelogWidgetExtension/      ← Widget + Live Activity (iOS)
└── server/                      ← Vercel middleware (Node.js/TypeScript)
    └── api/
        ├── pull.ts              ← GET  /api/pull
        └── sync.ts              ← POST /api/sync
```

## Layer dell'applicazione

```mermaid
graph TD
    subgraph iOS["App iOS (Timelog)"]
        iViews["Views iOS\nSwiftUI"]
        iSplash["SplashView"]
    end

    subgraph macOS["App macOS (TimelogMac)"]
        mViews["Views macOS\nSwiftUI"]
        mMenu["MenuBarExtra"]
    end

    subgraph Widget["Widget Extension"]
        wWidget["Widget Today\nLive Activity"]
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

    subgraph Infra["Infrastruttura"]
        SD[("SwiftData\nSQLite locale")]
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

## Regole architetturali

| Regola | Motivazione |
|--------|-------------|
| Business logic solo in `TimelogCore` | Le app contengono esclusivamente Views |
| Tutto `public` in TimelogCore | Visibile da entrambe le app e dalla widget |
| Un solo `ModelContainer` per app | Evita conflitti SwiftData; in macOS è `static let` condiviso tra WindowGroup e MenuBarExtra |
| iOS usa `RestSyncService`, macOS usa `MongoSyncService` | iOS non può usare MongoKitten (binario ARM-only, dipendenze pesanti); la stessa firma pubblica separa le implementazioni |
| `#if os(iOS)` per ActivityKit e UIKit haptics | Non usare `#if targetEnvironment(macCatalyst)` — il progetto non usa Catalyst |

## Dipendenze Package

```mermaid
graph LR
    TimelogCore["TimelogCore"]
    TimelogSync["TimelogSync"]
    MongoKitten["MongoKitten 7.9.0+\n(solo macOS)"]

    TimelogSync --> TimelogCore
    TimelogSync -->|"#if os(macOS)"| MongoKitten
```

## Entry point per piattaforma

### iOS — `TimelogApp.swift`
```
App
 └─ ModelContainer (Client, Project, TimeEntry, ActiveSession)
     └─ ZStack
         ├─ ContentView
         │   ├─ TabBar: Today · Clients · Timer · Settings
         │   ├─ RestSyncSetup (modifier — pull all'avvio, push debounced 2s)
         │   └─ SyncFlashOverlay (modifier — flash verde + haptic al sync)
         └─ SplashView (scompare dopo l'animazione iniziale)
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
 │       └─ MenuBarStatusLabel (mostra timer se in running)
 └─ Settings (⌘,)
     └─ MacSettingsView
```
