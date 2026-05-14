# Piano: rimozione MongoDB + CloudKit su iOS e macOS

**Obiettivo**: eliminare completamente MongoDB/MongoKitten e `TimelogSync`, e adottare
SwiftData + CloudKit come unico layer di sync su entrambe le piattaforme.
Zero costi aggiuntivi, zero dipendenze esterne, best practice Apple.

---

## Strategia

| | Prima | Dopo |
|---|---|---|
| iOS sync | no-op stub | SwiftData + CloudKit automatico |
| macOS sync | MongoKitten / MongoDB Atlas | SwiftData + CloudKit automatico |
| Package TimelogSync | MongoSyncService + MongoKitten | **eliminato** |
| Costi | MongoDB Atlas (free tier ma account) | iCloud gratis con Developer Program |

**Come funziona CloudKit + SwiftData**: si passa `cloudKitDatabase: .automatic` al
`ModelContainer`; Apple sincronizza i record in background senza scrivere una riga di
codice sync. Funziona offline, gestisce i conflitti, e usa l'account iCloud dell'utente.

---

## Step 1 — Abilitare iCloud/CloudKit in entrambi i target Xcode

Questo va fatto manualmente in Xcode (non modificabile via pbxproj in sicurezza):

### iOS (`Timelog.xcodeproj`)
1. Target **Timelog** → Signing & Capabilities → **+ Capability** → **iCloud**
2. Spuntare **CloudKit**, creare container `iCloud.me.albz.timelog`
3. Xcode aggiorna `Timelog/Timelog.entitlements` automaticamente

### macOS (`TimelogMac.xcodeproj`)
1. Target **TimelogMac** → Signing & Capabilities → **+ Capability** → **iCloud**
2. Selezionare lo stesso container `iCloud.me.albz.timelog`
3. Xcode aggiorna `TimelogMac/TimelogMac.entitlements` automaticamente

---

## Step 2 — Aggiornare i ModelContainer

### iOS — `Timelog/TimelogApp.swift`
```swift
// Prima:
.modelContainer(for: [Client.self, Project.self, TimeEntry.self, ActiveSession.self])

// Dopo: ActiveSession locale (no sync), resto su CloudKit
let syncedConfig = ModelConfiguration(
    "synced",
    schema: Schema([Client.self, Project.self, TimeEntry.self]),
    cloudKitDatabase: .automatic
)
let localConfig = ModelConfiguration(
    "local",
    schema: Schema([ActiveSession.self]),
    cloudKitDatabase: .none
)
// usato in WindowGroup con .modelContainer(try! ModelContainer(for: ..., configurations: ...))
```

### macOS — `TimelogMac/TimelogMacApp.swift`
Stessa identica configurazione (stesso container `iCloud.me.albz.timelog` → i dati si sincronizzano).

---

## Step 3 — Pulire TimelogApp.swift (iOS)
- Rimuovere la struct `MongoSyncSetup`
- Rimuovere `.modifier(MongoSyncSetup())`
- Rimuovere `import TimelogSync`

## Step 4 — Pulire TimelogMacApp.swift (macOS)
- Rimuovere la struct `MongoSyncSetup`
- Rimuovere `.modifier(MongoSyncSetup())`
- Rimuovere `import TimelogSync`

## Step 5 — Pulire MacSettingsView.swift
- Rimuovere la sezione "MongoDB Sync" (Sync Now, Reset & Pull, connection string)
- Rimuovere `MongoStatusDot`
- Rimuovere `import TimelogSync`
- Aggiungere (opzionale) una riga read-only che mostra lo stato iCloud

## Step 6 — Rimuovere TimelogSync dai target Xcode
- `Timelog.xcodeproj`: rimuovere `TimelogSync` da Frameworks del target Timelog
- `TimelogMac.xcodeproj`: rimuovere `TimelogSync` da Frameworks del target TimelogMac

## Step 7 — Eliminare il package TimelogSync
- Cancellare `TimelogCore/Sources/TimelogSync/` (directory e contenuto)
- In `TimelogCore/Package.swift`: rimuovere il prodotto `TimelogSync`, il target `TimelogSync`,
  e la dipendenza `MongoKitten`
- In `TimelogCore/Package.resolved`: si aggiorna da solo al prossimo resolve

---

## Note importanti

### ActiveSession non va sincronizzata
Una sessione aperta su iPhone non deve apparire su Mac come "in corso".
Va tenuta in un `ModelConfiguration` separato senza CloudKit (vedi Step 2).

### Proprietà opzionali
CloudKit richiede che tutte le properties dei modelli siano opzionali o abbiano un default.
Verificare `Client`, `Project`, `TimeEntry` — se ci sono `let` senza default potrebbero
dare errore a runtime. SwiftData di solito gestisce questo, ma vale la pena controllare.

### Primo avvio
I dati locali esistenti vengono caricati su CloudKit automaticamente al primo avvio
con il nuovo container. Nessuna migrazione manuale necessaria.

### Utente non loggato in iCloud
Il container funziona offline, il sync parte quando l'utente accede a iCloud.
Aggiungere eventualmente un banner in Settings se `CKContainer.default().accountStatus != .available`.

---

## File da toccare (in ordine)

| # | File | Azione |
|---|------|--------|
| 1 | Xcode UI | aggiungere capability iCloud a entrambi i target |
| 2 | `Timelog/TimelogApp.swift` | nuovo ModelContainer + rimuovi MongoSyncSetup |
| 3 | `TimelogMac/TimelogMacApp.swift` | nuovo ModelContainer + rimuovi MongoSyncSetup |
| 4 | `TimelogMac/Views/MacSettingsView.swift` | rimuovi sezione MongoDB |
| 5 | `Timelog.xcodeproj/project.pbxproj` | rimuovi link TimelogSync |
| 6 | `TimelogMac.xcodeproj/project.pbxproj` | rimuovi link TimelogSync |
| 7 | `TimelogCore/Sources/TimelogSync/` | eliminare directory |
| 8 | `TimelogCore/Package.swift` | rimuovi TimelogSync target + MongoKitten |
