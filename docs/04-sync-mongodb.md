# Synchronisation

The project uses two separate sync implementations, one per platform, both in the `TimelogSync` package.

| Platform | Service | Protocol |
|----------|---------|----------|
| iOS | `RestSyncService` | URLSession → Vercel Functions → MongoDB Atlas |
| macOS | `MongoSyncService` | MongoKitten → MongoDB Atlas (direct wire protocol) |

---

## iOS — RestSyncService

### Architecture

```mermaid
flowchart TD
    subgraph iOS["iOS App"]
        SD[("SwiftData\nlocal SQLite")]
        KCH[("Keychain\nrest_sync_server_url\nrest_sync_api_key")]
        File["SyncConfig.local\n(bundle, gitignored)"]
        RSS["RestSyncService\n@Observable @MainActor"]
    end

    subgraph Vercel["Vercel Functions"]
        Pull["GET /api/pull"]
        Sync["POST /api/sync"]
    end

    MDB[("MongoDB Atlas")]

    File -->|"loadConfigFromFile()\nif Keychain empty"| KCH
    KCH --> RSS

    MDB -->|"pullAll(into:)\non app launch"| Pull
    Pull -->|"{ clients, projects, entries }"| RSS
    RSS -->|"delete-all + re-insert"| SD

    SD -->|"onChange + debounce 2s"| RSS
    RSS -->|"POST payload"| Sync
    Sync -->|"upsert"| MDB
```

### Launch sequence

1. `loadConfigFromFile()` — reads `SyncConfig.local` from the bundle (URL + API_KEY), saves to Keychain if not already configured
2. `setDataProvider` — registers the closure that fetches all data from `container.mainContext`
3. `isPulling = true` — blocks push during pull to prevent loops
4. `pullAll(into:)`:
   - GET `/api/pull` with `X-API-Key` header
   - Post `willWipeDataNotification` → waits 150ms (lets views silence animations)
   - Delete TimeEntry, then Project, then Client from SwiftData
   - Re-insert from scratch in order: clients → projects → entries, linking relationships in memory
5. `isPulling = false` — `SyncFlashOverlay` shows green flash + haptic

### Auto-push

`onChange` on clients/projects/entries → `triggerSync()` (only if `!isPulling`) → debounce 2s → POST `/api/sync`

### Configuration

```bash
# Timelog/SyncConfig.local (gitignored, included in iOS bundle)
URL=https://your-app.vercel.app
API_KEY=your-secret-key
```

### Observable state

| Property | Type | Meaning |
|----------|------|---------|
| `isSyncing` | `Bool` | Pull or push in progress |
| `lastSyncDate` | `Date?` | Timestamp of last successful sync |
| `lastError` | `String?` | Last error (nil if OK) |
| `isConfigured` | `Bool` | URL and API key present in Keychain |

---

## macOS — MongoSyncService

### Architecture

```mermaid
flowchart TD
    subgraph macOS["macOS App"]
        SD[("SwiftData\nlocal SQLite")]
        KCH[("Keychain\nmongo_connection_string")]
        File["~/.config/timelog/mongo.local\n(outside repo, dev only)"]
        MSS["MongoSyncService\n@Observable @MainActor"]
    end

    subgraph MongoDB["MongoDB Atlas"]
        DB[("Database: timelog")]
        C1["clients"]
        C2["projects"]
        C3["time_entries"]
    end

    File -->|"loadConnectionStringFromFile()\nif Keychain empty"| KCH
    KCH -->|"connect()"| MSS

    MongoDB -->|"pullAll(into:)\nif SwiftData empty"| MSS
    MSS -->|"upsert into SwiftData"| SD

    SD -->|"NSManagedObjectContextDidSave\n+ triggerSync()"| MSS
    MSS -->|"upsertEncoded — push"| MongoDB

    C1 & C2 & C3 --- DB
```

### Launch sequence

1. `loadConnectionStringFromFile()` — reads `~/.config/timelog/mongo.local`, saves to Keychain if empty
2. `connect()` — opens the wire-protocol connection via MongoKitten
3. `pullAll(into:)` — executed **only if SwiftData is empty** (first launch or after manual reset), to avoid an empty-state flash
4. `triggerSync()` — immediate push of local data to Atlas

### Auto-push

`onChange` on clients/projects/entries → `triggerSync()` → debounce 2s → `upsertEncoded` on all three collections

### Configuration

```bash
mkdir -p ~/.config/timelog
echo "mongodb+srv://user:password@cluster.mongodb.net" > ~/.config/timelog/mongo.local
```

**Read priority:**
```
~/.config/timelog/mongo.local  (only if Keychain is empty)
         ↓
  Keychain "mongo_connection_string"
         ↓
    MongoSyncService.db
```

### Observable state

| Property | Type | Meaning |
|----------|------|---------|
| `isSyncing` | `Bool` | Pull or push in progress |
| `lastSyncDate` | `Date?` | Timestamp of last successful pull or push |
| `lastError` | `String?` | Last error (nil if OK) |

---

## MongoDB document schema (shared)

Documents are identical regardless of which platform wrote them (iOS via Vercel, macOS via MongoKitten).

### `clients`
```json
{ "_id": ObjectId("..."), "name": "Acme", "colorHex": "#FF5733", "isArchived": false, "deletedAt": null }
```

### `projects`
```json
{ "_id": ObjectId("..."), "name": "Website", "code": "PRJ-01", "isArchived": false, "clientMongoId": "64abc...", "deletedAt": null }
```

### `time_entries`
```json
{ "_id": ObjectId("..."), "date": "2025-05-15T09:00:00.000Z", "durationMinutes": 90, "notes": "...", "clientMongoId": "...", "projectMongoId": "...", "deletedAt": null }
```

### `sessions` (ActiveSession)
```json
{ "_id": ObjectId("..."), "startDate": "2025-05-15T09:00:00.000Z", "notes": "...", "clientMongoId": "...", "projectMongoId": "..." }
```

> **`deletedAt` note**: the field is `null` for active records, set to the deletion date for logically deleted records. During sync, records with `deletedAt != null` are removed from local SwiftData after pull.

---

## MongoId strategy

Every SwiftData entity has a `mongoId: String?` field used as the sync key by both implementations.

| Scenario | iOS (RestSyncService) | macOS (MongoSyncService) |
|----------|-----------------------|--------------------------|
| Pull — document found by mongoId | Update fields in-place | Update fields in-place |
| Pull — document not found | Create new entity with mongoId = server `_id` | Create new entity with mongoId = server `_id` |
| Push — `mongoId` present | Use as `_id` for upsert | Use as `ObjectId` for upsert |
| Push — `mongoId` absent | Leave empty (`""`) — server generates a new `_id` | Generate a new valid `ObjectId` |

> **iOS note**: pull is a full replacement (delete-all + re-insert), not an incremental upsert. This guarantees consistency without having to handle merge conflicts.
