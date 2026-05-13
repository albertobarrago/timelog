# Keychain keys — Timelog

## Il problema del socket

L'errore `socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL) failed: Operation not permitted`
viene da **Swift NIO** (usato da MongoKitten) quando prova ad aprire un socket di sistema
per monitorare i cambi di percorso di rete (`NWPathMonitor`). Su macOS, le app in sandbox
non possono aprirlo senza l'entitlement `com.apple.security.network.client`.

**Fix:** il file `TimelogMac/TimelogMac.entitlements` è stato creato. Devi assegnarlo
all'app in Xcode:

1. Apri `TimeLog.xcworkspace`
2. Seleziona il progetto `TimelogMac` nel navigator
3. Seleziona il target `TimelogMac`
4. Tab **Signing & Capabilities** → sezione *App Sandbox* → spunta **Outgoing Connections (Client)**

Xcode rileverà automaticamente il file `.entitlements` nella cartella del target.

---

## Dove vivono le chiavi nel Keychain (macOS)

### Dove fisicamente

Il Keychain di login si trova in:

```
~/Library/Keychains/login.keychain-db
```

Non aprire quel file direttamente — è binario cifrato. Ci sono due modi leggibili:

**1. GUI — Keychain Access**
```
/Applications/Utilities/Keychain Access.app
```
- Seleziona *login* nella sidebar
- Categoria *Password* o *Tutte le voci*
- Cerca `mongo_connection_string`

**2. CLI — tool `security`**
```bash
# Leggere una chiave
security find-generic-password -a "mongo_connection_string" -w

# Eliminare una chiave
security delete-generic-password -a "mongo_connection_string"

# Elencare tutte le voci generiche dell'app (filtra per nome)
security dump-keychain | grep "mongo"
```

---

## Chiavi usate da questa app

| Chiave (`kSecAttrAccount`) | Dove | Contenuto |
|---|---|---|
| `mongo_connection_string` | `MongoSyncService` | Connection string Atlas completa, es. `mongodb+srv://user:pass@host/` |

### Come è strutturata nel Keychain

`KeychainHelper` usa `kSecClassGenericPassword` con solo `kSecAttrAccount` impostato.
**Non imposta `kSecAttrService`**, quindi la voce non ha un "servizio" associato.
In Keychain Access la colonna *Where* risulta vuota o `""`).

> ⚠️ Attenzione: senza `kSecAttrService`, se un'altra app salva una chiave con lo stesso
> nome account, può sovrascriverla. Per ora non è un problema perché `mongo_connection_string`
> è un nome abbastanza specifico.

---

## Come aggiornare la connection string

Dall'app: **Settings → MongoDB Sync** → campo di testo → *Save & Connect*

Da terminale (utile per debug):
```bash
# Scrivere direttamente
security add-generic-password -a "mongo_connection_string" \
  -w "mongodb+srv://user:pass@host/timelog" -U

# Verificare cosa c'è salvato
security find-generic-password -a "mongo_connection_string" -w
```

---

## Note per il futuro

Se aggiungi altre chiavi (es. Wethod API key), il pattern da seguire in `KeychainHelper`
è sempre lo stesso, ma considera di aggiungere `kSecAttrService` con il bundle ID
(`me.albz.timelog`) per isolare le chiavi dell'app:

```swift
kSecAttrService as String: "me.albz.timelog",
kSecAttrAccount as String: key,
```
