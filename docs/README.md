# Timelog — Documentazione Tecnica

App di time tracking per iOS e macOS con sincronizzazione MongoDB Atlase e note di sviluppo.

## Indice

| File | Contenuto |
|------|-----------|
| [01-architettura.md](01-architettura.md) | Struttura monorepo, layer, dipendenze |
| [02-modello-dati.md](02-modello-dati.md) | Entità SwiftData, relazioni, persistenza |
| [03-flussi.md](03-flussi.md) | Tracking, Pomodoro, Notifiche, Live Activity |
| [04-sync-mongodb.md](04-sync-mongodb.md) | Architettura sync, connessione, upsert |
| notes/ | Note di sviluppo |

## Stack

| Livello | Tecnologia |
|---------|------------|
| UI | SwiftUI |
| State | `@Observable` (Swift 5.9+) |
| Persistenza locale | SwiftData |
| Sincronizzazione cloud | MongoDB Atlas via MongoKitten |
| Credenziali | Keychain |
| Notifiche | UNUserNotificationCenter |
| Live Activity | ActivityKit (iOS only) |
| Widget | WidgetKit |

## Requisiti

- iOS 17+ / macOS 14+
- Xcode 26+
- Swift 6.0
- Account MongoDB Atlas (opzionale, solo per sync macOS)
