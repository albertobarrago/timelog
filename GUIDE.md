# Timelog — Guida all'installazione su un nuovo Mac

## Requisiti

| Cosa | Versione minima |
|------|-----------------|
| macOS | 14 Sonoma (o superiore) |
| Xcode | 16+ |
| Git | qualsiasi versione recente |

---

## 1. Clona il repo

```bash
git clone <url-del-repo> ~/Code/Swift/TimeLog
cd ~/Code/Swift/TimeLog
```

> Se il repo è privato assicurati di avere SSH configurato o di fare login con `gh auth login`.

---

## 2. Apri il workspace

**Apri sempre `TimeLog.xcworkspace`**, non i singoli `.xcodeproj`.

```bash
open TimeLog.xcworkspace
```

oppure trascinalo in Xcode dal Finder.

---

## 3. Configura la firma (Signing)

1. Seleziona il progetto `TimelogMac` nel navigator di Xcode
2. Target **TimelogMac** → tab **Signing & Capabilities**
3. Spunta **Automatically manage signing**
4. Scegli il tuo **Team** (account Apple ID personale va bene)
5. Lascia che Xcode risolva i provisioning profile da solo

> Se non hai un Apple ID in Xcode: menu **Xcode → Settings → Accounts → +**

---

## 4. Build & Run

Seleziona lo schema **TimelogMac** e come destinazione il tuo Mac, poi:

```
⌘ R
```

L'app si avvia con la finestra principale **e** l'icona nella menu bar.

---

## 5. (Opzionale) Esportare un `.app` per portarlo senza Xcode

1. **Product → Archive** (schema TimelogMac, destinazione "Any Mac")
2. Nell'Organizer che si apre: **Distribute App → Copy App**
3. Salva il `.app` dove vuoi (es. `~/Desktop/Timelog.app`)
4. Copia `Timelog.app` nella cartella `/Applications` del Mac di lavoro

> Prima di aprirlo la prima volta: tasto destro → **Apri** (bypassa Gatekeeper per app non notarizzate).

---

## 6. Funzionalità attive subito

- **Menu bar** — icona orologio sempre visibile, mostra il timer in esecuzione
- **Finestra principale** — `⌘` clic sull'icona menu bar, oppure apri l'app normalmente
- **Preferenze** — `⌘,`
- **Dati** — salvati localmente in SwiftData (nessun account richiesto per usarla)

---

## Troubleshooting rapido

| Problema | Soluzione |
|----------|-----------|
| Build error su `TimelogCore` | Xcode → **File → Packages → Reset Package Caches** |
| Signing error "No account" | Aggiungi il tuo Apple ID in Xcode Settings → Accounts |
| App bloccata da Gatekeeper | Tasto destro → Apri, poi conferma |
| Menu bar non appare | Controlla che l'app sia in esecuzione in Activity Monitor |
