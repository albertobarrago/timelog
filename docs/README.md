# Timelog — Technical Documentation

Time tracking app for iOS and macOS with MongoDB Atlas synchronisation.

## Index

| File | Contents |
|------|----------|
| [01-architettura.md](01-architettura.md) | Monorepo structure, layers, dependencies |
| [02-modello-dati.md](02-modello-dati.md) | SwiftData entities, relationships, persistence |
| [03-flussi.md](03-flussi.md) | Tracking, Pomodoro, Notifications, Live Activity |
| [04-sync-mongodb.md](04-sync-mongodb.md) | Sync architecture, connection, upsert strategy |

## Stack

| Layer | Technology |
|-------|------------|
| UI | SwiftUI |
| State | `@Observable` (Swift 5.9+) |
| Local persistence | SwiftData |
| Cloud sync | MongoDB Atlas via MongoKitten |
| Credentials | Keychain |
| Notifications | UNUserNotificationCenter |
| Live Activity | ActivityKit (iOS only) |
| Widget | WidgetKit |

## Requirements

- iOS 17+ / macOS 14+
- Xcode 16+
- Swift 6.0
- MongoDB Atlas account (optional, macOS sync only)
