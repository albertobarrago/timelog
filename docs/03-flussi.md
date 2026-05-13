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
    I --> J[HomeView aggiornata\nMongoSync debounced 2s]
```

## 3. Timer Pomodoro

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

## 4. Notifiche

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

## 5. Live Activity (iOS)

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

## 6. Navigation — macOS

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

## 7. Navigation — iOS

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
