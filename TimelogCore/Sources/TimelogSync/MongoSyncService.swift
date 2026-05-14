import Foundation
import SwiftData
import TimelogCore

public enum MongoSyncError: LocalizedError {
    case noCredentials
    case notConnected

    public var errorDescription: String? {
        switch self {
        case .noCredentials: return "Connection string not found in Keychain."
        case .notConnected:  return "Not connected to MongoDB."
        }
    }
}

#if os(macOS)
import MongoKitten

private struct ClientDocument: Codable {
    var _id: ObjectId
    var name: String
    var colorHex: String
    var isArchived: Bool
    init(from client: Client) {
        _id = client.mongoId.flatMap { ObjectId($0) } ?? ObjectId()
        name = client.name; colorHex = client.colorHex; isArchived = client.isArchived
    }
}

private struct ProjectDocument: Codable {
    var _id: ObjectId
    var name: String
    var code: String?
    var isArchived: Bool
    var clientMongoId: String?
    init(from project: TimelogCore.Project) {
        _id = project.mongoId.flatMap { ObjectId($0) } ?? ObjectId()
        name = project.name; code = project.code; isArchived = project.isArchived
        clientMongoId = project.client?.mongoId
    }
}

private struct TimeEntryDocument: Codable {
    var _id: ObjectId
    var date: Date
    var durationMinutes: Int
    var notes: String?
    var clientMongoId: String?
    var projectMongoId: String?
    init(from entry: TimeEntry) {
        _id = entry.mongoId.flatMap { ObjectId($0) } ?? ObjectId()
        date = entry.date; durationMinutes = entry.durationMinutes; notes = entry.notes
        clientMongoId = entry.client?.mongoId; projectMongoId = entry.project?.mongoId
    }
}

@Observable
@MainActor
public final class MongoSyncService {
    public static let shared = MongoSyncService()
    public typealias DataProvider = () -> (clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry])

    private var db: MongoDatabase?
    private var dataProvider: DataProvider?
    private var debounceTask: Task<Void, Never>?

    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastError: String?

    public static let willWipeDataNotification = Notification.Name("MongoSyncServiceWillWipeData")
    private static let connectionStringKey = "mongo_connection_string"
    private static let debounceSeconds: Double = 2

    private init() {}

    public func saveConnectionString(_ s: String) { KeychainHelper.save(key: Self.connectionStringKey, value: s) }
    public func readConnectionString() -> String?  { KeychainHelper.read(key: Self.connectionStringKey) }

    public func loadConnectionStringFromFile() {
        guard readConnectionString() == nil else { return }
        let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/timelog/mongo.local")
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saveConnectionString(trimmed)
    }

    public func connect() async throws {
        guard let raw = KeychainHelper.read(key: Self.connectionStringKey) else { throw MongoSyncError.noCredentials }
        db = try await MongoDatabase.connect(to: resolvedConnectionString(raw))
    }

    private func resolvedConnectionString(_ raw: String) -> String {
        guard var c = URLComponents(string: raw) else { return raw }
        if c.path.isEmpty || c.path == "/" { c.path = "/timelog" }
        return c.string ?? raw
    }

    public func setDataProvider(_ provider: @escaping DataProvider) { dataProvider = provider }

    public func triggerSync() { scheduleDebounced() }

    public func stopAutoSync() { debounceTask?.cancel(); dataProvider = nil }

    private func scheduleDebounced() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.debounceSeconds))
            guard !Task.isCancelled, let self else { return }
            if self.db == nil {
                do { try await self.connect() } catch { self.lastError = error.localizedDescription; return }
            }
            guard let data = self.dataProvider?() else { return }
            try? await self.syncAll(clients: data.clients, projects: data.projects, entries: data.entries)
        }
    }

    public func syncAll(clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry]) async throws {
        guard let db else { throw MongoSyncError.notConnected }
        isSyncing = true; lastError = nil; defer { isSyncing = false }
        do {
            try await push(clients: clients, to: db)
            try await push(projects: projects, to: db)
            try await push(entries: entries, to: db)
            lastSyncDate = .now
        } catch { lastError = error.localizedDescription; throw error }
    }

    public func pullAll(into context: ModelContext) async throws {
        guard let db else { throw MongoSyncError.notConnected }
        isSyncing = true; lastError = nil; defer { isSyncing = false }
        do {
            NotificationCenter.default.post(name: MongoSyncService.willWipeDataNotification, object: nil)
            try await Task.sleep(for: .milliseconds(150))
            try context.delete(model: TimeEntry.self)
            try context.delete(model: TimelogCore.Project.self)
            try context.delete(model: Client.self)
            try context.save()
            try await pull(clientsInto: context, from: db)
            try await pull(projectsInto: context, from: db)
            try await pull(entriesInto: context, from: db)
            lastSyncDate = .now
        } catch { lastError = error.localizedDescription; throw error }
    }

    private func pull(clientsInto ctx: ModelContext, from db: MongoDatabase) async throws {
        let docs = try await db["clients"].find().decode(ClientDocument.self).drain()
        let remoteIds = Set(docs.map { $0._id.hexString })
        for doc in docs {
            let id = doc._id.hexString
            if let c = try? ctx.fetch(FetchDescriptor<Client>(predicate: #Predicate { $0.mongoId == id })).first {
                c.name = doc.name; c.colorHex = doc.colorHex; c.isArchived = doc.isArchived
            } else {
                let c = Client(name: doc.name, colorHex: doc.colorHex, isArchived: doc.isArchived)
                c.mongoId = id; ctx.insert(c)
            }
        }
        for local in (try? ctx.fetch(FetchDescriptor<Client>())) ?? [] {
            if let mid = local.mongoId, !remoteIds.contains(mid) { ctx.delete(local) }
        }
        try ctx.save()
    }

    private func pull(projectsInto ctx: ModelContext, from db: MongoDatabase) async throws {
        let docs = try await db["projects"].find().decode(ProjectDocument.self).drain()
        let remoteIds = Set(docs.map { $0._id.hexString })
        for doc in docs {
            let id = doc._id.hexString
            if let p = try? ctx.fetch(FetchDescriptor<TimelogCore.Project>(predicate: #Predicate { $0.mongoId == id })).first {
                p.name = doc.name; p.code = doc.code; p.isArchived = doc.isArchived
            } else {
                let p = TimelogCore.Project(name: doc.name, code: doc.code, isArchived: doc.isArchived)
                p.mongoId = id
                if let cid = doc.clientMongoId {
                    p.client = try? ctx.fetch(FetchDescriptor<Client>(predicate: #Predicate { $0.mongoId == cid })).first
                }
                ctx.insert(p)
            }
        }
        for local in (try? ctx.fetch(FetchDescriptor<TimelogCore.Project>())) ?? [] {
            if let mid = local.mongoId, !remoteIds.contains(mid) { ctx.delete(local) }
        }
        try ctx.save()
    }

    private func pull(entriesInto ctx: ModelContext, from db: MongoDatabase) async throws {
        let docs = try await db["time_entries"].find().decode(TimeEntryDocument.self).drain()
        for doc in docs {
            let id = doc._id.hexString
            if let e = try? ctx.fetch(FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.mongoId == id })).first {
                e.date = doc.date; e.durationMinutes = doc.durationMinutes; e.notes = doc.notes
            } else {
                let client = doc.clientMongoId.flatMap { cid in try? ctx.fetch(FetchDescriptor<Client>(predicate: #Predicate { $0.mongoId == cid })).first }
                let project = doc.projectMongoId.flatMap { pid in try? ctx.fetch(FetchDescriptor<TimelogCore.Project>(predicate: #Predicate { $0.mongoId == pid })).first }
                let e = TimeEntry(date: doc.date, durationMinutes: doc.durationMinutes, notes: doc.notes, client: client, project: project)
                e.mongoId = id; ctx.insert(e)
            }
        }
        try ctx.save()
    }

    private func push(clients: [Client], to db: MongoDatabase) async throws {
        let col = db["clients"]
        for c in clients { let doc = ClientDocument(from: c); try await col.upsertEncoded(doc, where: "_id" == doc._id) }
    }

    private func push(projects: [TimelogCore.Project], to db: MongoDatabase) async throws {
        let col = db["projects"]
        for p in projects { let doc = ProjectDocument(from: p); try await col.upsertEncoded(doc, where: "_id" == doc._id) }
    }

    private func push(entries: [TimeEntry], to db: MongoDatabase) async throws {
        let col = db["time_entries"]
        for e in entries { let doc = TimeEntryDocument(from: e); try await col.upsertEncoded(doc, where: "_id" == doc._id) }
    }
}

#else

// MARK: - iOS no-op stub

@Observable
@MainActor
public final class MongoSyncService {
    public static let shared = MongoSyncService()
    public typealias DataProvider = () -> (clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry])

    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastError: String?
    public static let willWipeDataNotification = Notification.Name("MongoSyncServiceWillWipeData")
    private static let connectionStringKey = "mongo_connection_string"

    private init() {}

    public func saveConnectionString(_ s: String) { KeychainHelper.save(key: Self.connectionStringKey, value: s) }
    public func readConnectionString() -> String?  { KeychainHelper.read(key: Self.connectionStringKey) }
    public func loadConnectionStringFromFile() {}
    public func connect() async throws {}
    public func setDataProvider(_ provider: @escaping DataProvider) {}
    public func triggerSync() {}
    public func stopAutoSync() {}
    public func syncAll(clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry]) async throws {}
    public func pullAll(into context: ModelContext) async throws {}
}

#endif
