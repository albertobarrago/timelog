import Foundation
import Testing
@testable import TimelogSync

@Suite("REST sync support")
struct RestSyncSupportTests {
    @Test func parsesSyncLocalConfigWithWhitespaceAndIgnoresUnknownKeys() {
        let raw = """
        URL = https://timelog.example.com/
        API_KEY = secret-key
        EXTRA = ignored
        """

        let config = RestSyncLocalConfig.parse(raw)

        #expect(config == RestSyncLocalConfig(
            serverURL: "https://timelog.example.com/",
            apiKey: "secret-key"
        ))
    }

    @Test func rejectsIncompleteSyncLocalConfig() {
        #expect(RestSyncLocalConfig.parse("URL=https://timelog.example.com") == nil)
        #expect(RestSyncLocalConfig.parse("API_KEY=secret-key") == nil)
        #expect(RestSyncLocalConfig.parse("URL=\nAPI_KEY=secret-key") == nil)
    }

    @Test func buildsPullURLWithEncodedUserId() throws {
        let url = try #require(RestSyncEndpoint.pullURL(
            base: "https://timelog.example.com/",
            userId: "user one"
        ))

        #expect(url.absoluteString == "https://timelog.example.com/api/pull?userId=user%20one")
    }

    @Test func buildsEventsURLUnderBasePath() throws {
        let url = try #require(RestSyncEndpoint.eventsURL(
            base: "https://timelog.example.com/v1/",
            userId: "albz"
        ))

        #expect(url.absoluteString == "https://timelog.example.com/v1/api/events?userId=albz")
    }
}
