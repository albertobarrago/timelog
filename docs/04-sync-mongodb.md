# Sincronizzazione MongoDB

> Disponibile solo su macOS. Su iOS `MongoSyncService` è uno stub no-op.

## Architettura

```mermaid
flowchart TD
    subgraph macOS["App macOS"]
        SD[("SwiftData\nSQLite locale")]
        KCH[("Keychain\nmongo_connection_string")]
        File["~/.config/timelog/mongo.local\n(gitignored, solo dev)"]
        MSS["MongoSyncService\n@Observable @MainActor"]
    end

    subgraph MongoDB["MongoDB Atlas"]
        DB[("Database: timelog")]
        C1["Collection: clients"]
        C2["Collection: projects"]
        C3["Collection: time_entries"]
    end

    File -->|"loadConnectionStringFromFile()\nse Keychain è vuota"| KCH
    KCH -->|"connect()"| MSS
    SD -->|"NSManagedObjectContextDidSave"| MSS
    MSS -->|"upsert"| C1
    MSS -->|"upsert"| C2
    MSS -->|"upsert"| C3
    C1 & C2 & C3 --> DB
```

## Flusso di connessione all'avvio

```mermaid
sequenceDiagram
    participant App as TimelogMacApp
    participant MSS as MongoSyncService
    participant File as mongo.local
    participant KCH as Keychain
    participant MDB as MongoDB Atlas

    App->>MSS: loadConnectionStringFromFile()
    MSS->>KCH: readConnectionString()
    alt Keychain vuota
        KCH-->>MSS: nil
        MSS->>File: legge ~/.config/timelog/mongo.local
        File-->>MSS: connection string raw
        MSS->>KCH: saveConnectionString(trimmed)
    else Keychain già popolata
        KCH-->>MSS: connection string
        Note over MSS: Salta lettura file
    end

    App->>MSS: connect() [async]
    MSS->>KCH: readConnectionString()
    KCH-->>MSS: connection string
    MSS->>MSS: resolvedConnectionString()\nAggiunge "/timelog" se path vuoto
    MSS->>MDB: MongoDatabase.connect(to: uri)
    MDB-->>MSS: MongoDatabase

    App->>MSS: startAutoSync(dataProvider:)
    MSS->>MSS: Registra observer\nNSManagedObjectContextDidSaveNotification
```

## Flusso di sync automatico

```mermaid
sequenceDiagram
    participant CTX as ModelContext (SwiftData)
    participant NC as NotificationCenter
    participant MSS as MongoSyncService
    participant MDB as MongoDB Atlas

    CTX->>NC: NSManagedObjectContextDidSaveNotification
    NC->>MSS: observer callback
    MSS->>MSS: scheduleDebounced()
    Note over MSS: Cancella task precedente\nAttende 2 secondi (debounce)

    alt db == nil
        MSS->>MSS: connect()
    end

    MSS->>MSS: dataProvider() — fetch da ModelContext
    MSS->>MSS: syncAll(clients:projects:entries:)

    loop per ogni Client
        MSS->>MDB: collection["clients"].upsertEncoded\n(where: _id == doc._id)
    end
    loop per ogni Project
        MSS->>MDB: collection["projects"].upsertEncoded\n(where: _id == doc._id)
    end
    loop per ogni TimeEntry
        MSS->>MDB: collection["time_entries"].upsertEncoded\n(where: _id == doc._id)
    end

    MSS->>MSS: lastSyncDate = .now
```

## Struttura documenti MongoDB

### `clients`
```json
{
  "_id": ObjectId("..."),
  "name": "Acme Corp",
  "colorHex": "#FF5733",
  "isArchived": false
}
```

### `projects`
```json
{
  "_id": ObjectId("..."),
  "name": "Website Redesign",
  "code": "PRJ-001",
  "isArchived": false,
  "clientMongoId": "64abc..."
}
```

### `time_entries`
```json
{
  "_id": ObjectId("..."),
  "date": ISODate("2025-05-13T09:00:00Z"),
  "durationMinutes": 90,
  "notes": "Implementazione login",
  "clientMongoId": "64abc...",
  "projectMongoId": "64def..."
}
```

## Configurazione connection string

### Sviluppo locale
Creare il file (una sola volta, mai committato):
```bash
mkdir -p ~/.config/timelog
echo "mongodb+srv://user:password@cluster.mongodb.net" > ~/.config/timelog/mongo.local
```

### Priorità di lettura
```
~/.config/timelog/mongo.local
         ↓ (solo se Keychain è vuota)
      Keychain "mongo_connection_string"
         ↓
   MongoSyncService.db
```

### Formato URI accettato
- `mongodb+srv://user:pass@cluster.mongodb.net` — Atlas (raccomandato)
- `mongodb://localhost:27017` — locale

Il service aggiunge automaticamente `/timelog` come database se il path è assente.

## Stati osservabili

| Proprietà | Tipo | Significato |
|-----------|------|-------------|
| `isSyncing` | `Bool` | Sync in corso |
| `lastSyncDate` | `Date?` | Timestamp ultimo sync riuscito |
| `lastError` | `String?` | Ultimo errore (nil se OK) |
