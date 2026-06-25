// setup-mongo.js — run once to create collections and indexes
// Usage: mongosh "mongodb+srv://..." /path/to/setup-mongo.js

const db = globalThis.db; // mongosh exposes db globally

const collections = ["clients", "projects", "time_entries", "active_sessions"];

for (const name of collections) {
  const existing = db.getCollectionNames();
  if (!existing.includes(name)) {
    db.createCollection(name);
    print(`Created collection: ${name}`);
  } else {
    print(`Collection already exists: ${name}`);
  }
}

// clients
db.clients.createIndex({ userId: 1 }, { background: true });
db.clients.createIndex({ userId: 1, deletedAt: 1 }, { background: true });

// projects
db.projects.createIndex({ userId: 1 }, { background: true });
db.projects.createIndex({ userId: 1, clientMongoId: 1 }, { background: true });

// time_entries
db.time_entries.createIndex({ userId: 1 }, { background: true });
db.time_entries.createIndex({ userId: 1, date: -1 }, { background: true });
db.time_entries.createIndex({ userId: 1, deletedAt: 1 }, { background: true });

// active_sessions
db.active_sessions.createIndex({ userId: 1 }, { background: true });

print("\nSetup complete. Collections and indexes are ready.");
