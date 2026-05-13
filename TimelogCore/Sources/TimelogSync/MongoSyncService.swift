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

// MARK: - BSON DTOs

private struct ClientDocument: Codable {
    var _id: ObjectId
    var name: String
    var colorHex: String
    var isArchived: Bool

    init(from client: Client) {
        _id = client.mongoId.flatMap { ObjectId($0) } ?? ObjectId()
        name = client.name
        colorHex = client.colorHex
        isArchived = client.isArchived
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
        name = project.name
        code = project.code
        isArchived = project.isArchived
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
        date = entry.date
        durationMinutes = entry.durationMinutes
        notes = entry.notes
        clientMongoId = entry.client?.mongoId
        projectMongoId = entry.project?.mongoId
    }
}

// MARK: - Service

@Observable
@MainActor
public final class MongoSyncService {
    public static let shared = MongoSyncService()

    public typealias DataProvider = () -> (clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry])

    private var db: MongoDatabase?
    private var dataProvider: DataProvider?
    private var debounceTask: Task<Void, Never>?
    private var observerToken: NSObjectProtocol?

    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastError: String?

    private static let connectionStringKey = "mongo_connection_string"
    private static let debounceSeconds: Double = 2

    private init() {}

    public func saveConnectionString(_ connectionString: String) {
        KeychainHelper.save(key: Self.connectionStringKey, value: connectionString)
    }

    public func readConnectionString() -> String? {
        KeychainHelper.read(key: Self.connectionStringKey)
    }

    /// Reads ~/.config/timelog/mongo.local and saves to Keychain if not already set.
    public func loadConnectionStringFromFile() {
        guard readConnectionString() == nil else { return }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config/timelog/mongo.local")
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saveConnectionString(trimmed)
    }

    public func connect() async throws {
        guard let raw = KeychainHelper.read(key: Self.connectionStringKey) else {
            throw MongoSyncError.noCredentials
        }
        db = try await MongoDatabase.connect(to: resolvedConnectionString(raw))
    }

    private func resolvedConnectionString(_ raw: String) -> String {
        guard var components = URLComponents(string: raw) else { return raw }
        if components.path.isEmpty || components.path == "/" {
            components.path = "/timelog"
        }
        return components.string ?? raw
    }

    public func startAutoSync(dataProvider: @escaping DataProvider) {
        self.dataProvider = dataProvider
        observerToken = NotificationCenter.default.addObserver(
            forName: Notification.Name("NSManagedObjectContextDidSaveNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleDebounced()
            }
        }
    }

    public func triggerSync() {
        scheduleDebounced()
    }

    public func stopAutoSync() {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
            observerToken = nil
        }
        debounceTask?.cancel()
        dataProvider = nil
    }

    private func scheduleDebounced() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.debounceSeconds))
            guard !Task.isCancelled, let self else { return }
            if self.db == nil {
                do {
                    try await self.connect()
                } catch {
                    self.lastError = error.localizedDescription
                    return
                }
            }
            guard let data = self.dataProvider?() else { return }
            try? await self.syncAll(clients: data.clients, projects: data.projects, entries: data.entries)
        }
    }

    public func syncAll(clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry]) async throws {
        guard let db else { throw MongoSyncError.notConnected }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }
        do {
            try await push(clients: clients, to: db)
            try await push(projects: projects, to: db)
            try await push(entries: entries, to: db)
            lastSyncDate = .now
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Pull (MongoDB → SwiftData)

    public func pullAll(into context: ModelContext) async throws {
        guard let db else { throw MongoSyncError.notConnected }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }
        do {
            try await pull(clientsInto: context, from: db)
            try await pull(projectsInto: context, from: db)
            try await pull(entriesInto: context, from: db)
            lastSyncDate = .now
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    private func pull(clientsInto context: ModelContext, from db: MongoDatabase) async throws {
        let docs = try await db["clients"].find().decode(ClientDocument.self).drain()
        for doc in docs {
            let id = doc._id.hexString
            let existing = try? context.fetch(FetchDescriptor<Client>(
                predicate: #Predicate { $0.mongoId == id }
            )).first
            if let c = existing {
                c.name      = doc.name
                c.colorHex  = doc.colorHex
                c.isArchived = doc.isArchived
            } else {
                let c = Client(name: doc.name, colorHex: doc.colorHex, isArchived: doc.isArchived)
                c.mongoId = id
                context.insert(c)
            }
        }
        try context.save()
    }

    private func pull(projectsInto context: ModelContext, from db: MongoDatabase) async throws {
        let docs = try await db["projects"].find().decode(ProjectDocument.self).drain()
        for doc in docs {
            let id = doc._id.hexString
            let existing = try? context.fetch(FetchDescriptor<TimelogCore.Project>(
                predicate: #Predicate { $0.mongoId == id }
            )).first
            if let p = existing {
                p.name       = doc.name
                p.code       = doc.code
                p.isArchived = doc.isArchived
            } else {
                let p = TimelogCore.Project(name: doc.name, code: doc.code, isArchived: doc.isArchived)
                p.mongoId = id
                if let cid = doc.clientMongoId {
                    p.client = try? context.fetch(FetchDescriptor<Client>(
                        predicate: #Predicate { $0.mongoId == cid }
                    )).first
                }
                context.insert(p)
            }
        }
        try context.save()
    }

    private func pull(entriesInto context: ModelContext, from db: MongoDatabase) async throws {
        let docs = try await db["time_entries"].find().decode(TimeEntryDocument.self).drain()
        for doc in docs {
            let id = doc._id.hexString
            let existing = try? context.fetch(FetchDescriptor<TimeEntry>(
                predicate: #Predicate { $0.mongoId == id }
            )).first
            if let e = existing {
                e.date            = doc.date
                e.durationMinutes = doc.durationMinutes
                e.notes           = doc.notes
            } else {
                var client: Client?
                var project: TimelogCore.Project?
                if let cid = doc.clientMongoId {
                    client = try? context.fetch(FetchDescriptor<Client>(
                        predicate: #Predicate { $0.mongoId == cid }
                    )).first
                }
                if let pid = doc.projectMongoId {
                    project = try? context.fetch(FetchDescriptor<TimelogCore.Project>(
                        predicate: #Predicate { $0.mongoId == pid }
                    )).first
                }
                let e = TimeEntry(date: doc.date, durationMinutes: doc.durationMinutes,
                                  notes: doc.notes, client: client, project: project)
                e.mongoId = id
                context.insert(e)
            }
        }
        try context.save()
    }

    // MARK: - Push (SwiftData → MongoDB)

    private func push(clients: [Client], to db: MongoDatabase) async throws {
        let collection = db["clients"]
        for client in clients {
            let doc = ClientDocument(from: client)
            try await collection.upsertEncoded(doc, where: "_id" == doc._id)
        }
    }

    private func push(projects: [TimelogCore.Project], to db: MongoDatabase) async throws {
        let collection = db["projects"]
        for project in projects {
            let doc = ProjectDocument(from: project)
            try await collection.upsertEncoded(doc, where: "_id" == doc._id)
        }
    }

    private func push(entries: [TimeEntry], to db: MongoDatabase) async throws {
        let collection = db["time_entries"]
        for entry in entries {
            let doc = TimeEntryDocument(from: entry)
            try await collection.upsertEncoded(doc, where: "_id" == doc._id)
        }
    }
}

#else

// MARK: - iOS stub (MongoDB sync not available on iOS)

@Observable
@MainActor
public final class MongoSyncService {
    public static let shared = MongoSyncService()
    public typealias DataProvider = () -> (clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry])

    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastError: String?

    private static let connectionStringKey = "mongo_connection_string"

    private init() {}

    public func saveConnectionString(_ connectionString: String) {
        KeychainHelper.save(key: Self.connectionStringKey, value: connectionString)
    }

    public func readConnectionString() -> String? {
        KeychainHelper.read(key: Self.connectionStringKey)
    }

    public func loadConnectionStringFromFile() {}

    public func connect() async throws {}
    public func startAutoSync(dataProvider: @escaping DataProvider) {}
    public func triggerSync() {}
    public func stopAutoSync() {}
    public func pullAll(into context: ModelContext) async throws {}
    public func syncAll(clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry]) async throws {}
}

#endif
