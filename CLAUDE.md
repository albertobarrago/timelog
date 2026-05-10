# Timelog — Project Context for Claude

## Struttura monorepo

Questo repo contiene **due app** e **un package condiviso**. Vanno sempre tenuti di pari passo.

```
TimeLog/
├── TimeLog.xcworkspace        ← apri SEMPRE questo, non i .xcodeproj singoli
├── Timelog.xcodeproj          ← app iOS
├── TimelogMac.xcodeproj       ← app macOS nativa
├── TimelogCore/               ← Swift Package locale condiviso da entrambe
│   └── Sources/TimelogCore/
│       ├── Models/            ← Client, Project, TimeEntry, ActiveSession
│       ├── ViewModels/        ← TimerViewModel
│       ├── Stores/            ← SettingsStore
│       ├── Helpers/           ← KeychainHelper, NotificationManager
│       └── Extensions/        ← Color+Hex, Int+Duration
├── Timelog/                   ← sorgenti iOS (solo Views)
├── TimelogMac/                ← sorgenti macOS (solo Views)
└── TimelogWidgetExtension/    ← Live Activity widget (iOS only)
```

## Regole fondamentali

- **Business logic → TimelogCore**. Modelli, stores, helpers, ViewModels vivono nel package. Le app contengono solo Views.
- **Tipi pubblici**. Tutto in TimelogCore deve avere `public` su class/struct/enum, properties, init e metodi.
- **Piattaforme**. `#if os(iOS)` per ActivityKit e UIKit haptics. `#if os(macOS)` per AppKit. Non usare `#if targetEnvironment(macCatalyst)` — il progetto iOS è iOS puro, nessun Catalyst.
- **Un solo ModelContainer** nell'app macOS (`TimelogMacApp`), condiviso tra WindowGroup e MenuBarExtra tramite `static let container`.
- **Non pushare mai senza chiedere** all'utente.

## App iOS (`Timelog.xcodeproj`)

- Target: iPhone + iPad, iOS 17+
- Nessun Mac Catalyst
- Live Activity su lock screen + Dynamic Island (`TimelogWidgetExtensionExtension`)
- Widget extension versione (`CFBundleVersion`) deve sempre coincidere con la main app
- Tab order: Today → Clients → Timer → Settings

## App macOS (`TimelogMac.xcodeproj`)

- Target: macOS 14+ nativo
- `MenuBarExtra` → icona nella menu bar di sistema (sempre visibile)
- `WindowGroup` → finestra principale con `NavigationSplitView` (sidebar: Today / Clients / Timer / Settings)
- `Settings` scene → accessibile via `⌘,`
- Toolbar items nei detail view, **non** sul `NavigationSplitView` root
- `columnVisibility` come `@State` (non `.constant`) per permettere il toggle sidebar

## Package TimelogCore

- `Package.swift`: platforms `.iOS(.v17)`, `.macOS(.v14)`
- Tutto `public` — se aggiungi un tipo nuovo ricordati di mettere `public init()`
- Conditional compilation per piattaforme specifiche:
  - ActivityKit → `#if os(iOS) && !targetEnvironment(macCatalyst)`
  - UIKit haptics → `#if os(iOS)` (anche la firma della funzione, non solo il body)
  - AppKit → `#if canImport(AppKit) && !targetEnvironment(macCatalyst)`

## Commit e git

- **Mai pushare senza chiedere** all'utente
- Nessun `Co-Authored-By` nei commit message
- I due `.xcodeproj` e `TimelogCore/` sono tutti nello stesso repo e nello stesso commit quando cambiano insieme

## Stack tecnico

- SwiftUI + SwiftData + `@Observable`
- Keychain per API key Wethod
- `UNUserNotificationCenter` per reminder giornalieri, alert sessioni aperte, fine fase Pomodoro
- `ActivityKit` per Live Activity iOS
- `MenuBarExtra` per status bar macOS
