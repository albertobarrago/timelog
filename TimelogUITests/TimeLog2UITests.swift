//
//  TimeLog2UITests.swift
//  TimeLog2UITests
//
//  Created by Alberto Barrago on 10/05/2026.
//

import XCTest

final class TimeLog2UITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testLaunchesToMainTabs() throws {
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Timer"].exists)
        XCTAssertTrue(app.tabBars.buttons["More"].exists)
    }
}
