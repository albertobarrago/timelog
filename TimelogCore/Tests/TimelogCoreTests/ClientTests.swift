import Testing
import Foundation
@testable import TimelogCore

@Suite("Client")
struct ClientTests {

    @Test func mongoIdIs24Characters() {
        #expect(Client.newMongoId().count == 24)
    }

    @Test func mongoIdIsLowercaseHex() {
        let id = Client.newMongoId()
        #expect(id.allSatisfy { $0.isHexDigit && ($0.isNumber || $0.isLowercase) })
    }

    @Test func mongoIdIsUnique() {
        #expect(Client.newMongoId() != Client.newMongoId())
    }
}
