import Testing
@testable import TimelogCore

@Suite("Int.formattedDuration")
struct IntDurationTests {

    @Test(arguments: [
        (0,    "0m"),
        (1,    "1m"),
        (30,   "30m"),
        (59,   "59m"),
        (60,   "1h"),
        (61,   "1h 1m"),
        (90,   "1h 30m"),
        (119,  "1h 59m"),
        (120,  "2h"),
        (1440, "24h"),
    ] as [(Int, String)])
    func formattedDuration(input: Int, expected: String) {
        #expect(input.formattedDuration == expected)
    }
}
