# Flussi Utente

## 1. Time Tracking — Avvio e Stop

```mermaid
sequenceDiagram
    actor U as Utente
    participant V as HomeView
    participant SS as StartTrackingSheet
    participant CTX as ModelContext
    participant NM as NotificationManager
    participant LA as LiveActivity (iOS)

    U->>V: Tap "Avvia sessione"
    V->>SS: Apre sheet
    U->>SS: Seleziona Client e/o Project
    U->>SS: Tap "Avvia"
    SS->>CTX: insert(ActiveSession)
    CTX-->>V: Aggiorna lista sessioni attive
    SS->>NM: scheduleSessionOverdue(id, endHour, endMinute)
    SS->>LA: startLiveActivity() [solo iOS]
    LA-->>U: Lock screen + Dynamic Island attivi

    Note over V: Timer tick ogni 60s (TimelineView)

    U->>V: Tap "Stop" sulla sessione
    V->>StopSheet: Apre sheet con durata stimata
    U->>StopSheet: Conferma durata (minuti)
    StopSheet->>CTX: insert(TimeEntry)
    StopSheet->>CTX: delete(ActiveSession)
    CTX-->>V: Lista aggiornata
    StopSheet->>NM: cancelSession(id)
    StopSheet->>LA: endLiveActivity() [solo iOS]
```

## 2. Quick Log (log manuale)

```mermaid
flowchart TD
    A([Tap Quick Log]) --> B[Sheet QuickLogSheet]
    B --> C{Client selezionato?}
    C -->|No| D[Log senza client]
    C -->|Sì| E{Project selezionato?}
    E -->|No| F[Log solo con client]
    E -->|Sì| G[Log con client e project]
    D & F & G --> H[insert TimeEntry\ncon date=oggi, durationMinutes, notes]
    H --> I[Chiude sheet]
    I --> J[HomeView aggiornata\nSync debounced 2s\niOS: RestSyncService · macOS: MongoSyncService]
```

## 3. Sync iOS — RestSyncService

```mermaid
sequenceDiagram
    participant App as TimelogApp (onAppear)
    participant RSS as RestSyncService
    participant KCH as Keychain
    participant File as SyncConfig.local (bundle)
    participant SD as SwiftData
    participant VCL as Vercel Functions

    App->>RSS: loadConfigFromFile()
    RSS->>File: legge SyncConfig.local (URL + API_KEY)
    RSS->>KCH: saveConfig(serverURL, apiKey)

    App->>RSS: setDataProvider { container.mainContext }
    Note over App: isPulling = true

    App->>RSS: pullAll(into: modelContext) [async]
    RSS->>VCL: GET /api/pull  X-API-Key: ...
    VCL-->>RSS: { clients, projects, entries }

    RSS->>SD: post willWipeDataNotification
    RSS->>SD: delete all TimeEntry / Project / Client
    RSS->>SD: insert clients → save
    RSS->>SD: insert projects (link client) → save
    RSS->>SD: insert entries (link client+project) → save
    RSS->>RSS: lastSyncDate = .now
    Note over App: isPulling = false\nSyncFlashOverlay: flash verde + haptic

    Note over App: onChange(clients/projects/entries)
    App->>RSS: triggerSync() [se !isPulling]
    RSS->>RSS: debounce 2s
    RSS->>SD: fetch tutti i dati via dataProvider
    RSS->>VCL: POST /api/sync { clients, projects, entries }
    RSS->>RSS: lastSyncDate = .now
```

## 4. Sync macOS — MongoSyncService

```mermaid
sequenceDiagram
    participant App as TimelogMacApp (onAppear)
    participant MSS as MongoSyncService
    participant KCH as Keychain
    participant File as mongo.local
    participant SD as SwiftData
    participant MDB as MongoDB Atlas

    App->>MSS: loadConnectionStringFromFile()
    MSS->>KCH: readConnectionString()
    alt Keychain vuota
        KCH-->>MSS: nil
        MSS->>File: legge ~/.config/timelog/mongo.local
        MSS->>KCH: saveConnectionString(trimmed)
    end

    App->>MSS: setDataProvider { container.mainContext }
    App->>MSS: connect() [async]
    MSS->>MDB: MongoDatabase.connect(uri)

    alt SwiftData vuoto (primo avvio)
        App->>MSS: pullAll(into: modelContext)
        MSS->>MDB: find all clients/projects/time_entries
        MDB-->>MSS: documenti
        MSS->>SD: upsert per mongoId → context.save()
    end

    App->>MSS: triggerSync()
    MSS->>SD: dataProvider() — fetch tutti i dati
    MSS->>MDB: upsertEncoded su clients/projects/time_entries
    MSS->>MSS: lastSyncDate = .now

    Note over App: onChange(clients/projects/entries)
    App->>MSS: triggerSync()
    MSS->>MSS: debounce 2s → push
```

## 5. Timer Pomodoro

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Work : toggle() - pomodoroEnabled=true
    Idle --> FreeRun : toggle() - pomodoroEnabled=false

    FreeRun --> Idle : toggle() (pause/reset)

    Work --> WorkPaused : toggle()
    WorkPaused --> Work : toggle()
    Work --> ShortBreak : phaseComplete()\ncompletedPomodoros % pomodorosBeforeLong ≠ 0
    Work --> LongBreak : phaseComplete()\ncompletedPomodoros % pomodorosBeforeLong == 0

    ShortBreak --> ShortBreakPaused : toggle()
    ShortBreakPaused --> ShortBreak : toggle()
    ShortBreak --> Work : phaseComplete()

    LongBreak --> LongBreakPaused : toggle()
    LongBreakPaused --> LongBreak : toggle()
    LongBreak --> Work : phaseComplete()
```

### Transizione di fase — dettaglio

```mermaid
sequenceDiagram
    participant T as TimerViewModel
    participant NM as NotificationManager
    participant H as Haptics (iOS)
    participant LA as LiveActivity (iOS)

    T->>T: tick() ogni 1 secondo
    T->>T: elapsed >= phaseTotal?

    alt Fase completata
        T->>NM: schedulePomodoroEnd(phase, in: 0)
        T->>H: UIImpactFeedbackGenerator.heavy [solo iOS]
        T->>T: completedPomodoros++ (se Work)
        T->>T: phase = nextPhase()
        T->>T: elapsed = 0
        T->>LA: updateLiveActivity(phase, isRunning) [solo iOS]
    end
```

## 6. Notifiche

```mermaid
flowchart LR
    subgraph Tipi["Tipi di notifica"]
        R["Reminder giornaliero\n'Time to log your hours!'"]
        S["Sessione aperta\n'You have an open session'"]
        P["Pomodoro completato\n'Work phase done!'"]
    end

    subgraph Trigger
        RS["SettingsStore.applyReminders()\n→ reschedule(hour, minute, days)"]
        SS2["StartTrackingSheet\n→ scheduleSessionOverdue(...)"]
        PP["TimerViewModel.phaseComplete()\n→ schedulePomodoroEnd(...)"]
    end

    subgraph Cancel
        CR["cancelAllReminders()\nse reminderEnabled=false"]
        CS["StopSessionSheet\n→ cancelSession(id)"]
        CP["Nuovo tick di fase\n→ cancelPomodoroNotification()"]
    end

    RS --> R
    SS2 --> S
    PP --> P
    CR -.-> R
    CS -.-> S
    CP -.-> P
```

## 7. Live Activity (iOS)

```mermaid
sequenceDiagram
    participant VM as TimerViewModel
    participant AK as ActivityKit
    participant LS as Lock Screen / Dynamic Island

    VM->>AK: Activity.request(attributes, contentState)
    AK-->>LS: Mostra "timer in corso"

    loop ogni 1 secondo
        VM->>VM: tick() — elapsed++
        VM->>AK: activity.update(contentState)
        AK-->>LS: Aggiorna displayTime
    end

    VM->>AK: activity.end(dismissalPolicy: .immediate)
    AK-->>LS: Rimuove Live Activity
```

## 8. Navigation — macOS

```mermaid
flowchart TD
    MenuBar["MenuBarExtra\n(sempre visibile)"] -->|click| MBV["MenuBarView\n(window style)"]
    MBV --> QA["Quick actions:\nAvvia · Stoppa · Quick Log"]

    Dock["WindowGroup 'main'"] --> MMV["MainMacView\nNavigationSplitView"]
    MMV -->|"Today"| TV["TodayMacView"]
    MMV -->|"Clients"| CV["ClientsMacView → ProjectsMacView"]
    MMV -->|"Tracking"| TRV["TimerMacView"]
    MMV -->|"Settings"| SV["MacSettingsView"]

    Cmd,["⌘,"] --> Prefs["Settings scene\nMacSettingsView"]
```

## 9. Navigation — iOS

```mermaid
flowchart TD
    App["TimelogApp"] --> Tab["TabView"]
    Tab -->|"Today"| H["HomeView"]
    Tab -->|"Clients"| C["ClientsView"]
    Tab -->|"Timer"| T["TimerView"]
    Tab -->|"Settings"| S["SettingsView"]

    H -->|"sheet"| ST["StartTrackingSheet"]
    H -->|"sheet"| SP["StopSessionSheet"]
    H -->|"sheet"| QL["QuickLogSheet"]
    H -->|"NavigationLink"| HV["HistoryView"]

    C -->|"NavigationLink"| PL["ProjectListView"]
    PL -->|"sheet"| PF["ProjectFormView"]
    C -->|"sheet"| CF["ClientFormView"]
```
