import Testing
import SwiftUI
@testable import TimelogCore

@Suite("Color+Hex")
struct ColorHexTests {

    @Test func parsesWithHash() {
        #expect(Color(hex: "#AABBCC") != nil)
    }

    @Test func parsesWithoutHash() {
        #expect(Color(hex: "AABBCC") != nil)
    }

    @Test func parsesTrimmingWhitespace() {
        #expect(Color(hex: "  #AABBCC  ") != nil)
    }

    @Test func rejectsNonHexCharacters() {
        #expect(Color(hex: "GGHHII") == nil)
    }

    @Test func rejectsWrongLength() {
        #expect(Color(hex: "#AAB") == nil)
        #expect(Color(hex: "#AABBCCDD") == nil)
    }

    @Test func roundTripBlack() {
        #expect(Color(hex: "#000000")?.hex == "#000000")
    }

    @Test func roundTripWhite() {
        #expect(Color(hex: "#FFFFFF")?.hex == "#FFFFFF")
    }

    // La conversione tramite AppKit non è esatta per valori intermedi (gamma/color space).
    // Verifica che la seconda passata sia stabile (idempotente).
    @Test func hexConversionIsIdempotent() {
        let color = Color(hex: "#336699")
        let first = color?.hex
        let second = first.flatMap { Color(hex: $0)?.hex }
        #expect(first != nil)
        #expect(first == second)
    }
}
