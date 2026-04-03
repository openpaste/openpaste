//
//  OpenPasteUITests.swift
//  OpenPasteUITests
//
//  Created by Lê Anh Tuấn on 1/4/26.
//

import XCTest

final class OpenPasteUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // Template placeholder test. Launching the real app from here can be flaky when
        // OpenPaste is already running on the developer machine.
        throw XCTSkip("Template UI test is skipped by default")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // Performance tests are intentionally opt-in because they are sensitive to
        // machine load and can be flaky in CI / shared dev environments.
        let env = ProcessInfo.processInfo.environment
        guard env["RUN_PERFORMANCE_TESTS"] == "1" else {
            throw XCTSkip("Set RUN_PERFORMANCE_TESTS=1 to enable launch performance measurement")
        }

        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
