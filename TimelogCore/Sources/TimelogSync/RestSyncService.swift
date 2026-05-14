import Foundation
import SwiftData
import TimelogCore

// MARK: - Errors

public enum RestSyncError: LocalizedError {
    case httpError(Int, String)
    public var errorDescription: String? {
        if case .httpError(let code, let body) = self { return "HTTP \(code): \(body)" }
        return nil
    }
}

// MARK: - DTOs

private struct PullResponse: Decodable {
    var clients:  [ClientDTO]
    var projects: [ProjectDTO]
    var entries:  [EntryDTO]
}

private struct ClientDTO: Codable {
    var _id: String
    var name: String
    var colorHex: String?
    var isArchived: Bool?
}

private struct ProjectDTO: Codable {
    var _id: String
    var name: String
    var code: String?
    var isArchived: Bool?
    var clientMongoId: String?
}

private struct EntryDTO: Codable {
    var _id: String
    var date: String?
    var durationMinutes: Int?
    var notes: String?
    var clientMongoId: String?
    var projectMongoId: String?
}

private struct SyncPayload: Encodable {
    var clients:  [ClientDTO]
    var projects: [ProjectDTO]
    var entries:  [EntryDTO]
}

// MARK: - Service

@Observable
@MainActor
public final class RestSyncService {
    public static let shared = RestSyncService()

    public typealias DataProvider = () -> (clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry])

    private var dataProvider: DataProvider?
    private var debounceTask: Task<Void, Never>?

    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastError: String?

    public static let willWipeDataNotification = Notification.Name("RestSyncServiceWillWipeData")

    private static let serverURLKey = "rest_sync_server_url"
    private static let apiKeyKey    = "rest_sync_api_key"
    private static let debounceSeconds: Double = 2

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private init() {}

    // MARK: - Config (Keychain)

    public func saveConfig(serverURL: String, apiKey: String) {
        KeychainHelper.save(key: Self.serverURLKey, value: serverURL)
        KeychainHelper.save(key: Self.apiKeyKey, value: apiKey)
    }

    public func readServerURL() -> String? { KeychainHelper.read(key: Self.serverURLKey) }
    public func readApiKey()    -> String? { KeychainHelper.read(key: Self.apiKeyKey) }

    public var isConfigured: Bool { readServerURL() != nil && readApiKey() != nil }

    /// macOS: legge ~/.config/timelog/sync.local
    /// iOS:   legge SyncConfig.local dal bundle (gitignored, mai pushato)
    /// In entrambi i casi salva in Keychain e non sovrascrive se già configurato.
    public func loadConfigFromFile() {
        #if os(macOS)
        let fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config/timelog/sync.local")
        #else
        guard let fileURL = Bundle.main.url(forResource: "SyncConfig", withExtension: "local") else { return }
        #endif
        guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        var serverURL: String?
        var apiKey: String?
        for line in raw.components(separatedBy: .newlines) {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0].trimmingCharacters(in: .whitespaces) {
            case "URL":     serverURL = parts[1].trimmingCharacters(in: .whitespaces)
            case "API_KEY": apiKey    = parts[1].trimmingCharacters(in: .whitespaces)
            default: break
            }
        }
        if let u = serverURL, let k = apiKey, !u.isEmpty, !k.isEmpty {
            saveConfig(serverURL: u, apiKey: k)
        }
    }

    // MARK: - Sync control

    public func setDataProvider(_ provider: @escaping DataProvider) { dataProvider = provider }

    public func triggerSync() { scheduleDebounced() }

    public func stopAutoSync() { debounceTask?.cancel(); dataProvider = nil }

    private func scheduleDebounced() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.debounceSeconds))
            guard !Task.isCancelled, let self else { return }
            guard let data = self.dataProvider?() else { return }
            do {
                try await self.push(clients: data.clients, projects: data.projects, entries: data.entries)
            } catch {
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Pull (server → SwiftData)

    public func pullAll(into context: ModelContext) async throws {
        guard let url = serverURL(path: "/api/pull") else { return }
        isSyncing = true; lastError = nil; defer { isSyncing = false }

        let response: PullResponse = try await get(url: url)

        NotificationCenter.default.post(name: Self.willWipeDataNotification, object: nil)
        try await Task.sleep(for: .milliseconds(150))

        // Batch delete bypassa SwiftData observation — delete one by one
        for e in (try? context.fetch(FetchDescriptor<TimeEntry>())) ?? []          { context.delete(e) }
        for p in (try? context.fetch(FetchDescriptor<TimelogCore.Project>())) ?? [] { context.delete(p) }
        for c in (try? context.fetch(FetchDescriptor<Client>())) ?? []              { context.delete(c) }
        try context.save()

        for dto in response.clients {
            let c = Client(name: dto.name, colorHex: dto.colorHex ?? "#007AFF", isArchived: dto.isArchived ?? false)
            c.mongoId = dto._id
            context.insert(c)
        }
        try context.save()

        for dto in response.projects {
            let p = TimelogCore.Project(name: dto.name, code: dto.code, isArchived: dto.isArchived ?? false)
            p.mongoId = dto._id
            if let cid = dto.clientMongoId {
                p.client = try? context.fetch(FetchDescriptor<Client>(predicate: #Predicate { $0.mongoId == cid })).first
            }
            context.insert(p)
        }
        try context.save()

        for dto in response.entries {
            let dateStr = dto.date ?? ""
            let date = Self.iso8601.date(from: dateStr) ?? Self.iso8601NoFrac.date(from: dateStr) ?? Date()
            let client  = dto.clientMongoId.flatMap  { cid in try? context.fetch(FetchDescriptor<Client>(predicate: #Predicate { $0.mongoId == cid })).first }
            let project = dto.projectMongoId.flatMap { pid in try? context.fetch(FetchDescriptor<TimelogCore.Project>(predicate: #Predicate { $0.mongoId == pid })).first }
            let e = TimeEntry(date: date, durationMinutes: dto.durationMinutes ?? 0, notes: dto.notes, client: client, project: project)
            e.mongoId = dto._id
            context.insert(e)
        }
        try context.save()

        lastSyncDate = .now
    }

    // MARK: - Push (SwiftData → server)

    private func push(clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry]) async throws {
        guard let url = serverURL(path: "/api/sync") else { return }
        isSyncing = true; lastError = nil; defer { isSyncing = false }

        let payload = SyncPayload(
            clients: clients.map { ClientDTO(_id: $0.mongoId ?? "", name: $0.name, colorHex: $0.colorHex, isArchived: $0.isArchived) },
            projects: projects.map { ProjectDTO(_id: $0.mongoId ?? "", name: $0.name, code: $0.code, isArchived: $0.isArchived, clientMongoId: $0.client?.mongoId) },
            entries: entries.map { EntryDTO(_id: $0.mongoId ?? "", date: Self.iso8601.string(from: $0.date), durationMinutes: $0.durationMinutes, notes: $0.notes, clientMongoId: $0.client?.mongoId, projectMongoId: $0.project?.mongoId) }
        )
        try await post(url: url, body: payload)
        lastSyncDate = .now
    }

    // MARK: - HTTP helpers

    private func serverURL(path: String) -> URL? {
        guard let base = readServerURL() else { return nil }
        return URL(string: base.trimmingCharacters(in: .init(charactersIn: "/")) + path)
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue(readApiKey(), forHTTPHeaderField: "X-API-Key")
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[RestSync] GET \(url.path) → \(status)")
        print("[RestSync] body: \(String(data: data, encoding: .utf8) ?? "<non-utf8>")")
        guard status == 200 else {
            throw RestSyncError.httpError(status, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Encodable>(url: URL, body: T) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(readApiKey(), forHTTPHeaderField: "X-API-Key")
        req.httpBody = try JSONEncoder().encode(body)
        _ = try await URLSession.shared.data(for: req)
    }
}
