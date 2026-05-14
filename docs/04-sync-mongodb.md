# Sincronizzazione

Il progetto usa due implementazioni di sync distinte, una per piattaforma, entramben nello stesso package `TimelogSync`.

| Piattaforma | Servizio | Protocollo |
|-------------|----------|------------|
| iOS | `RestSyncService` | URLSession → Vercel Functions → MongoDB Atlas |
| macOS | `MongoSyncService` | MongoKitten → MongoDB Atlas (wire protocol diretto) |

---

## iOS — RestSyncService

### Architettura

```mermaid
flowchart TD
    subgraph iOS["App iOS"]
        SD[("SwiftData\nSQLite locale")]
        KCH[("Keychain\nrest_sync_server_url\nrest_sync_api_key")]
        File["SyncConfig.local\n(bundle, gitignored)"]
        RSS["RestSyncService\n@Observable @MainActor"]
    end

    subgraph Vercel["Vercel Functions"]
        Pull["GET /api/pull"]
        Sync["POST /api/sync"]
    end

    MDB[("MongoDB Atlas")]

    File -->|"loadConfigFromFile()\nse Keychain è vuota"| KCH
    KCH --> RSS

    MDB -->|"pullAll(into:)\navvio app"| Pull
    Pull -->|"{ clients, projects, entries }"| RSS
    RSS -->|"delete-all + re-insert"| SD

    SD -->|"onChange + debounce 2s"| RSS
    RSS -->|"POST payload"| Sync
    Sync -->|"upsert"| MDB
```

### Sequenza all'avvio

1. `loadConfigFromFile()` — legge `SyncConfig.local` dal bundle (URL + API_KEY), salva in Keychain se non già configurato
2. `setDataProvider` — registra la closure per fetchare tutti i dati da `container.mainContext`
3. `isPulling = true` — blocca il push durante il pull per evitare loop
4. `pullAll(into:)`:
   - GET `/api/pull` con header `X-API-Key`
   - Post `willWipeDataNotification` → attende 150ms (lascia silenziare le view)
   - Cancella TimeEntry, poi Project, poi Client da SwiftData
   - Reinserisce da zero nell'ordine clients → projects → entries, linkando le relazioni in memoria
5. `isPulling = false` — `SyncFlashOverlay` mostra flash verde + haptic

### Auto-push

`onChange` su clients/projects/entries → `triggerSync()` (solo se `!isPulling`) → debounce 2s → POST `/api/sync`

### Configurazione

```bash
# Timelog/SyncConfig.local (gitignored, incluso nel bundle iOS)
URL=https://your-app.vercel.app
API_KEY=your-secret-key
```

### Stati osservabili

| Proprietà | Tipo | Significato |
|-----------|------|-------------|
| `isSyncing` | `Bool` | Pull o push in corso |
| `lastSyncDate` | `Date?` | Timestamp ultimo sync riuscito |
| `lastError` | `String?` | Ultimo errore (nil se OK) |
| `isConfigured` | `Bool` | URL e API key presenti in Keychain |

---

## macOS — MongoSyncService

### Architettura

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

    MongoDB -->|"pullAll(into:)\nse SwiftData vuoto"| MSS
    MSS -->|"upsert in SwiftData"| SD

    SD -->|"NSManagedObjectContextDidSave\n+ triggerSync()"| MSS
    MSS -->|"upsertEncoded — push"| MongoDB

    C1 & C2 & C3 --- DB
```

### Sequenza all'avvio

1. `loadConnectionStringFromFile()` — legge `~/.config/timelog/mongo.local`, salva in Keychain se vuota
2. `connect()` — apre la connessione wire protocol con MongoKitten
3. `pullAll(into:)` — eseguito **solo se SwiftData è vuoto** (primo avvio o dopo reset manuale), per evitare il flash di empty state
4. `triggerSync()` — push immediato dei dati locali verso Atlas

### Auto-push

`onChange` su clients/projects/entries → `triggerSync()` → debounce 2s → `upsertEncoded` su tutte e tre le collection

### Configurazione

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

### Stati osservabili

| Proprietà | Tipo | Significato |
|-----------|------|-------------|
| `isSyncing` | `Bool` | Pull o push in corso |
| `lastSyncDate` | `Date?` | Timestamp ultimo pull o push riuscito |
| `lastError` | `String?` | Ultimo errore (nil se OK) |

---

## Struttura documenti MongoDB (condivisa)

I documenti sono identici indipendentemente da chi li ha scritti (iOS via Vercel, macOS via MongoKitten).

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
{ "_id": ObjectId("..."), "date": "2025-05-15T09:00:00.000Z", "durationMinutes": 90, "notes": "...", "clientMongoId": "...", "projectMongoId": "..." }
```

---

## Strategia MongoId

Ogni entità SwiftData ha un campo `mongoId: String?` usato come chiave di sincronizzazione in entrambe le implementazioni.

| Scenario | iOS (RestSyncService) | macOS (MongoSyncService) |
|----------|-----------------------|--------------------------|
| Pull — documento trovato per mongoId | Aggiorna i campi in-place | Aggiorna i campi in-place |
| Pull — documento non trovato | Crea nuova entità con mongoId = `_id` del server | Crea nuova entità con mongoId = `_id` del server |
| Push — `mongoId` presente | Usa come `_id` per l'upsert | Usa come `ObjectId` per l'upsert |
| Push — `mongoId` assente | Lascia vuoto (`""`) — il server genera un nuovo `_id` | Genera un nuovo `ObjectId` valido |

> **Nota iOS**: il pull è un rimpiazzo completo (delete-all + re-insert), non un upsert incrementale. Questo garantisce coerenza senza dover gestire conflitti di merge.
