# Modello Dati

## Entità e relazioni

```mermaid
erDiagram
    CLIENT {
        String  name
        String  colorHex
        Bool    isArchived
        String  mongoId
    }
    PROJECT {
        String  name
        String  code        "opzionale"
        Bool    isArchived
        String  mongoId
    }
    TIME_ENTRY {
        Date    date
        Int     durationMinutes
        String  notes       "opzionale"
        String  mongoId
    }
    ACTIVE_SESSION {
        Date    startDate
        String  notes       "opzionale"
        String  notificationID
    }

    CLIENT ||--o{ PROJECT       : "ha"
    CLIENT ||--o{ TIME_ENTRY    : "fatturata a"
    CLIENT ||--o| ACTIVE_SESSION : "in corso per"
    PROJECT ||--o{ TIME_ENTRY   : "registrata su"
    PROJECT ||--o| ACTIVE_SESSION : "in corso su"
```

## Descrizione entità

### `Client`
Rappresenta un cliente. Contiene la lista di progetti (cascade delete) e viene usato come riferimento nelle TimeEntry e nelle ActiveSession.

- `colorHex` — colore identificativo in formato `#RRGGBB`, esposto come `Color` via `Color+Hex`
- `mongoId` — `ObjectId` MongoDB serializzato come stringa (assegnato al primo upsert)
- Relazione con `Project`: deleteRule `.cascade` — eliminare un client rimuove tutti i suoi progetti

### `Project`
Progetto associato a un client. Il campo `code` è opzionale (codice commessa, es. "PRJ-001").

- Relazione con `TimeEntry`: deleteRule `.nullify` — eliminare un progetto non elimina le entry, le slega
- `mongoId` — come sopra

### `TimeEntry`
Record di tempo loggato. È la struttura dati principale dell'app.

- `durationMinutes` — durata in minuti interi; formattato tramite `Int.formattedDuration` ("1h 30m")
- `client` e `project` opzionali — una entry può essere non assegnata

### `ActiveSession`
Sessione di tracking in corso. Può esisterne al massimo una per client/progetto attivo.

- `elapsedDisplay` — stringa `"HH:MM:SS"` calcolata a runtime da `startDate`
- `elapsedMinutes` — intero calcolato, usato per stimare la durata prima dello stop
- `notificationID` — ID della notifica UNUserNotification per il promemoria di sessione aperta; cancellata allo stop

## Persistenza

```mermaid
flowchart LR
    App["App\n(iOS / macOS)"] -->|"read/write"| SD[("SwiftData\nSQLite locale")]
    SD -->|"NSManagedObjectContextDidSave"| Sync["MongoSyncService\n(macOS)"]
    Sync -->|"upsert"| MDB[("MongoDB Atlas")]

    Widget["Widget Extension"] -->|"read"| AppGroup[("App Group\nUserDefaults\nWidgetSnapshotStore")]
    App -->|"write snapshot"| AppGroup
```

### WidgetSnapshotStore
I widget non accedono a SwiftData direttamente. L'app scrive un snapshot serializzato in un `App Group` condiviso (`group.me.albz.timelog`).

```
TimelogWidgetSnapshot
 ├─ date: Date
 ├─ loggedMinutes: Int          ← minuti loggati oggi
 ├─ activeSessions: [...]       ← sessioni attive
 ├─ lastClientName: String?
 └─ lastProjectName: String?
```

## MongoId e strategia di upsert

Ogni entità ha un campo `mongoId: String?` che viene popolato al primo sync su MongoDB. La logica è:

1. Se `mongoId == nil` → crea un nuovo `ObjectId` e assegna
2. Se `mongoId != nil` → usa l'`ObjectId` esistente per l'upsert (`where: "_id" == doc._id`)

Questo permette di usare SwiftData come source of truth locale e MongoDB come replica cloud, senza conflitti di ID.
