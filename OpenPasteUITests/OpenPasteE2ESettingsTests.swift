import XCTest

final class OpenPasteE2ESettingsTests: XCTestCase {
    private let bundleID = "dev.tuanle.OpenPaste"

    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateRunningOpenPasteIfNeeded()
    }

    override func tearDownWithError() throws {
        terminateRunningOpenPasteIfNeeded()
    }

    // MARK: - Tests

    @MainActor
    func testE2E_SettingsWindow_AppearsWithAllSections() throws {
        let app = launchApp()
        defer { app.terminate() }

        openSettingsViaMenu(app: app)

        let settingsWindow = app.windows.firstMatch
        XCTAssertTrue(
            settingsWindow.waitForExistence(timeout: 10),
            "Expected Settings window to appear"
        )

        // Verify sidebar sections are present.
        let expectedSections = ["General", "Privacy", "Keyboard", "Appearance", "Storage", "About"]
        for section in expectedSections {
            let sectionLabel = settingsWindow.descendants(matching: .staticText)[section]
            XCTAssertTrue(
                sectionLabel.waitForExistence(timeout: 5),
                "Expected '\(section)' section in Settings sidebar"
            )
        }
    }

    @MainActor
    func testE2E_SettingsWindow_NavigatesBetweenSections() throws {
        let app = launchApp()
        defer { app.terminate() }

        openSettingsViaMenu(app: app)

        let settingsWindow = app.windows.firstMatch
        XCTAssertTrue(
            settingsWindow.waitForExistence(timeout: 10),
            "Expected Settings window to appear"
        )

        // Click through each section and verify the detail pane updates.
        let sectionChecks: [(section: String, marker: String)] = [
            ("General", "Permissions"),
            ("Privacy", "Ignore Applications"),
            ("Keyboard", "Keyboard"),
            ("Appearance", "Theme"),
            ("Storage", "Overview"),
            ("About", "About"),
        ]

        for check in sectionChecks {
            let sidebarItem = settingsWindow.descendants(matching: .staticText)[check.section]
            guard sidebarItem.waitForExistence(timeout: 3) else {
                XCTFail("Sidebar item '\(check.section)' not found")
                continue
            }
            sidebarItem.click()

            let marker = settingsWindow.descendants(matching: .any)[check.marker]
            XCTAssertTrue(
                marker.waitForExistence(timeout: 5),
                "Expected '\(check.marker)' content after clicking '\(check.section)'"
            )
        }
    }

    // MARK: - Helpers

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["OPENPASTE_UI_TEST_MODE"] = "1"
        app.launch()
        app.activate()
        return app
    }

    private func openSettingsViaMenu(app: XCUIApplication) {
        // Use Cmd+, keyboard shortcut to open the SwiftUI Settings window.
        app.typeKey(",", modifierFlags: .command)
    }

    private func terminateRunningOpenPasteIfNeeded() {
        var running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard !running.isEmpty else { return }

        for app in running {
            app.terminate()
        }

        let softDeadline = Date().addingTimeInterval(3)
        while Date() < softDeadline {
            running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if running.isEmpty { return }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }

        for app in running {
            _ = app.forceTerminate()
        }
    }
}
