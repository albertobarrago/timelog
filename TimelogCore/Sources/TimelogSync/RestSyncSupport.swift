import Foundation

struct RestSyncLocalConfig: Equatable {
    let serverURL: String
    let apiKey: String

    static func parse(_ raw: String) -> RestSyncLocalConfig? {
        var serverURL: String?
        var apiKey: String?

        for line in raw.components(separatedBy: .newlines) {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            switch key {
            case "URL":
                serverURL = value
            case "API_KEY":
                apiKey = value
            default:
                break
            }
        }

        guard let serverURL, let apiKey, !serverURL.isEmpty, !apiKey.isEmpty else {
            return nil
        }

        return RestSyncLocalConfig(serverURL: serverURL, apiKey: apiKey)
    }
}

enum RestSyncEndpoint {
    static func serverURL(base: String, path: String) -> URL? {
        URL(string: base.trimmingCharacters(in: .init(charactersIn: "/")) + path)
    }

    static func pullURL(base: String, userId: String) -> URL? {
        guard let baseURL = serverURL(base: base, path: "/api/pull") else { return nil }
        guard !userId.isEmpty,
              var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL
        }

        comps.queryItems = (comps.queryItems ?? []) + [URLQueryItem(name: "userId", value: userId)]
        return comps.url ?? baseURL
    }

    static func eventsURL(base: String, userId: String) -> URL? {
        let trimmed = base.trimmingCharacters(in: .init(charactersIn: "/"))
        guard var comps = URLComponents(string: trimmed) else { return nil }
        comps.path = (comps.path.isEmpty ? "" : comps.path) + "/api/events"
        comps.queryItems = [URLQueryItem(name: "userId", value: userId)]
        return comps.url
    }
}
