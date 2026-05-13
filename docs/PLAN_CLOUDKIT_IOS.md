# Piano: CloudKit sync per iOS

**Obiettivo**: sostituire il no-op MongoDB stub iOS con un sync nativo via CloudKit + SwiftData, così iPhone e Mac condividono gli stessi dati senza dipendenze esterne e senza costi aggiuntivi.

---

## Passi

### 1. Abilitare iCloud in Xcode (iOS target)
- `Timelog.xcodeproj` → Target **Timelog** → Signing & Capabilities → "+ Capability" → **iCloud**
- Spuntare **CloudKit** e creare/selezionare il container (es. `iCloud.me.albz.timelog`)
- Xcode aggiorna automaticamente `Timelog.entitlements` con `com.apple.developer.icloud-container-identifiers` e `com.apple.developer.ubiquity-kvstore-identifier`

### 2. Aggiornare il ModelContainer iOS
In `TimelogApp.swift`, sostituire:
```swift
.modelContainer(for: [Client.self, Project.self, TimeEntry.self, ActiveSession.self])
```
con:
```swift
.modelContainer(for: [Client.self, Project.self, TimeEntry.self, ActiveSession.self],
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic)
```
SwiftData gestisce il sync CloudKit in automatico — nessun codice extra.

### 3. Rimuovere MongoSyncSetup da iOS
- Eliminare `.modifier(MongoSyncSetup())` da `TimelogApp.body`
- Rimuovere la struct `MongoSyncSetup` da `TimelogApp.swift`
- Rimuovere `import TimelogSync`

### 4. Scollegare TimelogSync dall'iOS target
In `Timelog.xcodeproj` → Target **Timelog** → Frameworks, Libraries → rimuovere `TimelogSync`.
Il package resta nel repo per macOS, ma iOS non lo linka più.

### 5. Compatibilità macOS
Il Mac continua a usare `MongoSyncSetup` + MongoKitten come adesso.
CloudKit e MongoDB coesistono senza conflitti perché usano store SwiftData separati
(CloudKit usa `default.store`, MongoDB usa lo stesso ma fa upsert — ok se un solo device scrive per tipo).

> **Nota**: se si vuole sync bidirezionale Mac ↔ iPhone via CloudKit anche sul Mac,
> si può migrare `TimelogMacApp` allo stesso pattern in un secondo momento.

### 6. Test
- Buildare su simulatore iOS 17+ e device
- Creare un entry su iPhone → verificare che compaia su Mac (e viceversa) entro qualche secondo
- Controllare `CKContainer.default().accountStatus` per gestire il caso "iCloud non loggato"

---

## File coinvolti
| File | Modifica |
|------|----------|
| `Timelog/TimelogApp.swift` | rimuovi `MongoSyncSetup`, aggiorna `modelContainer` |
| `Timelog.xcodeproj/project.pbxproj` | aggiungi capability iCloud + rimuovi link TimelogSync |
| `Timelog/Timelog.entitlements` | aggiunto da Xcode automaticamente |
| `TimelogCore/Package.swift` | nessuna modifica |
| `TimelogCore/Sources/TimelogSync/` | nessuna modifica (macOS lo usa ancora) |

---

## Rischi / note
- **Primo avvio dopo migrazione**: i dati locali già presenti vengono caricati su CloudKit automaticamente da SwiftData.
- **Utente non loggato in iCloud**: il container funziona in locale, il sync parte appena accede. Da gestire con un banner opzionale in Settings.
- **ActiveSession**: considera se sincronizzarla su CloudKit — potrebbe creare conflitti se una sessione è aperta su entrambi i device. Valuta di escluderla: `ModelConfiguration` separata non-CloudKit solo per `ActiveSession`.
