# Sincronizzazione MongoDB

> Disponibile solo su macOS. Su iOS `MongoSyncService` è uno stub no-op.

## Architettura — sync bidirezionale

```mermaid
flowchart TD
    subgraph macOS["App macOS"]
        SD[("SwiftData\nSQLite locale")]
        KCH[("Keychain\nmongo_connection_string")]
        File["~/.config/timelog/mongo.local\n(fuori dal repo, solo dev)"]
        MSS["MongoSyncService\n@Observable @MainActor"]
    end

    subgraph MongoDB["MongoDB Atlas"]
        DB[("Database: timelog")]
        C1["clients"]
        C2["projects"]
        C3["time_entries"]
    end

    File -->|"loadConnectionStringFromFile()\nse Keychain è vuota"| KCH
    KCH -->|"connect()"| MSS

    MongoDB -->|"pullAll(into:) — avvio"| MSS
    MSS -->|"upsert in SwiftData"| SD

    SD -->|"NSManagedObjectContextDidSave\n+ triggerSync()"| MSS
    MSS -->|"upsertEncoded — push"| MongoDB

    C1 & C2 & C3 --- DB
```

## Sequenza completa all'avvio

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

    App->>MSS: startAutoSync(dataProvider:)
    Note over MSS: Registra observer NSManagedObjectContextDidSave

    App->>MSS: connect() [async]
    MSS->>MDB: MongoDatabase.connect(uri)
    MDB-->>MSS: MongoDatabase

    App->>MSS: pullAll(into: modelContext) [async]
    Note over MSS,SD: Pull MongoDB → SwiftData

    MSS->>MDB: db["clients"].find().decode(ClientDocument.self).drain()
    MDB-->>MSS: [ClientDocument]
    MSS->>SD: upsert clients by mongoId → context.save()

    MSS->>MDB: db["projects"].find().decode(ProjectDocument.self).drain()
    MDB-->>MSS: [ProjectDocument]
    MSS->>SD: upsert projects + link client → context.save()

    MSS->>MDB: db["time_entries"].find().decode(TimeEntryDocument.self).drain()
    MDB-->>MSS: [TimeEntryDocument]
    MSS->>SD: upsert entries + link client/project → context.save()

    MSS->>MSS: lastSyncDate = .now
    Note over App: SyncSuccessBanner appare per 3 secondi

    App->>MSS: triggerSync()
    Note over MSS: Push locale → MongoDB (debounce 2s)
    MSS->>SD: dataProvider() — fetch tutti i dati
    MSS->>MDB: upsertEncoded su clients/projects/time_entries
```

## Flusso auto-sync (dopo ogni modifica)

```mermaid
sequenceDiagram
    participant CTX as ModelContext
    participant NC as NotificationCenter
    participant MSS as MongoSyncService
    participant MDB as MongoDB Atlas

    CTX->>NC: NSManagedObjectContextDidSaveNotification
    NC->>MSS: observer callback
    MSS->>MSS: scheduleDebounced()
    Note over MSS: Cancella task precedente\nAttende 2 secondi

    MSS->>MSS: dataProvider() — fetch da container.mainContext
    MSS->>MSS: syncAll(clients:projects:entries:)

    loop per ogni Client/Project/TimeEntry
        MSS->>MDB: collection.upsertEncoded(doc, where: _id == doc._id)
    end
    MSS->>MSS: lastSyncDate = .now
```

## Strategia upsert — pull

| Caso | Azione |
|------|--------|
| `mongoId` trovato in SwiftData | Aggiorna `name`, `colorHex`, `isArchived`, ecc. |
| `mongoId` NON trovato | Crea nuova entità, sovrascrive l'`mongoId` auto-generato con quello di MongoDB |
| Relazioni (`clientMongoId`, `projectMongoId`) | Risolte cercando in SwiftData per `mongoId` dopo il save dei parent |

## Strategia upsert — push

Ogni entità ha un `mongoId: String?` inizializzato con bytes UUID serializzati (`prefix(12)` → 24 hex). Al primo push, `ObjectId(mongoId)` potrebbe fallire → viene generato un nuovo `ObjectId` valido e usato come `_id` in MongoDB. Il `mongoId` locale rimane invariato (le collisioni sono gestite dall'upsert on `_id`).

## Struttura documenti MongoDB

### `clients`
```json
{ "_id": ObjectId("..."), "name": "Acme", "colorHex": "#FF5733", "isArchived": false }
```

### `projects`
```json
{ "_id": ObjectId("..."), "name": "Website", "code": "PRJ-01", "isArchived": false, "clientMongoId": "64abc..." }
```

### `time_entries`
```json
{ "_id": ObjectId("..."), "date": ISODate("..."), "durationMinutes": 90, "notes": "...", "clientMongoId": "...", "projectMongoId": "..." }
```

## Configurazione connection string

```bash
mkdir -p ~/.config/timelog
echo "mongodb+srv://user:password@cluster.mongodb.net" > ~/.config/timelog/mongo.local
```

**Priorità di lettura:**
```
~/.config/timelog/mongo.local  (solo se Keychain è vuota)
         ↓
  Keychain "mongo_connection_string"
         ↓
    MongoSyncService.db
```

## Stati osservabili

| Proprietà | Tipo | Significato |
|-----------|------|-------------|
| `isSyncing` | `Bool` | Pull o push in corso |
| `lastSyncDate` | `Date?` | Timestamp ultimo pull o push riuscito |
| `lastError` | `String?` | Ultimo errore (nil se OK) |
