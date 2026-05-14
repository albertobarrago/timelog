# Timelog — Project Context for Claude

## Project Context
- Primary projects are native SwiftUI apps (Timelog for iOS/macOS) and a custom statusbar script — NOT Flutter, NOT the Markasso project unless explicitly named
- When user says 'status bar', they mean their custom shell script statusline, not Claude Code's built-in one or any project's UI

## Git & Commits
- **Mai aggiungere Claude come co-autore**, contributor, o credito in commit, README, o sezioni About — salvo esplicita richiesta
- **Commit locali OK** — chiedere sempre conferma prima di `git push` verso il remote

## SwiftUI/Swift Conventions
- Per ternary expressions che ritornano `ButtonStyle` diversi, usare `@ViewBuilder` per evitare errori di type inference
- Quando si aggiungono feature di sync/data, implementare **sempre sia push che pull**
- Referenziare sempre `modelContext` via `@Environment` — non assumere che sia in scope
- Verificare il targeting multipiattaforma (iOS + macOS) quando si creano nuovi target o file Xcode

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

## Package TimelogSync

- Contiene `MongoSyncService` — sync bidirezionale SwiftData ↔ MongoDB Atlas
- `pullAll(into:)` scarica tutto da MongoDB → SwiftData all'avvio (multi-device, multi-utente)
- Auto-push tramite `NSManagedObjectContextDidSaveNotification` con debounce 2 secondi
- macOS: implementazione completa con MongoKitten 7.9+
- iOS: stub no-op (stessa firma pubblica, nessun codice)
- Connection string: `~/.config/timelog/mongo.local` → Keychain (mai nel repo)

## Qualità da App Store / pubblicazione

Questo progetto è destinato alla pubblicazione. Rispettare sempre:

- **Accessibilità**: ogni elemento interattivo deve avere `.accessibilityLabel` significativo; non usare solo colore per comunicare stato
- **Localizzazione**: usare `String(localized:)` o `LocalizedStringKey` per tutte le stringhe UI; non stringhe hardcoded in italiano/inglese mescolate
- **Privacy**: nessun dato utente in log, nessuna analytics senza consenso, connection string mai in chiaro nel codice
- **Sicurezza**: credenziali solo in Keychain, mai in `UserDefaults` o `@AppStorage`
- **Performance**: nessun fetch SwiftData nel `body` delle view — usare `@Query`; operazioni pesanti in `Task` asincrono
- **Crash safety**: `try!` e `fatalError` solo per errori di programmazione (es. ModelContainer init); mai per dati utente o network
- **UI nativa macOS**: usare `LabeledContent`, `Form.grouped`, toolbar items, `NavigationSplitView` — non portare pattern iOS su macOS
- **UI nativa iOS**: usare sheet, swipe actions, `TabView` — non portare pattern macOS su iOS
- **Versioning**: `CFBundleShortVersionString` (marketing) e `CFBundleVersion` (build) devono essere consistenti tra app e widget extension

## Stack tecnico

- SwiftUI + SwiftData + `@Observable`
- Keychain per API key Wethod e MongoDB connection string
- `UNUserNotificationCenter` per reminder giornalieri, alert sessioni aperte, fine fase Pomodoro
- `ActivityKit` per Live Activity iOS
- `MenuBarExtra` per status bar macOS
- `MongoKitten` per sync MongoDB Atlas (macOS only)
