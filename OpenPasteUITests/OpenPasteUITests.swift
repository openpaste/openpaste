//
//  OpenPasteUITests.swift
//  OpenPasteUITests
//
//  Created by Lê Anh Tuấn on 1/4/26.
//

import AppKit
import Darwin
import XCTest

final class OpenPasteUITests: XCTestCase {
    private let bundleID = "dev.tuanle.OpenPaste"

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

    @MainActor
    func testLocalSparkleUpdateFromInstalledApp() throws {
        let env = ProcessInfo.processInfo.environment
        let feedPath = "/tmp/OpenPasteSparkleTest/feed/appcast.xml"
        let fallbackAppPath = "/Users/\(NSUserName())/Applications/OpenPaste.app"
        let appPath = env["OPENPASTE_E2E_APP_PATH"] ?? fallbackAppPath
        let expectedVersion = env["OPENPASTE_E2E_EXPECTED_VERSION"] ?? "1.3.1"
        let isEnabled = env["RUN_LOCAL_SPARKLE_E2E"] == "1"

        let appExists = FileManager.default.fileExists(atPath: appPath)
        let feedExists = FileManager.default.fileExists(atPath: feedPath)
        print(
            "LocalSparkleDebug home=\(NSHomeDirectory()) appPath=\(appPath) appExists=\(appExists) feedPath=\(feedPath) feedExists=\(feedExists) enabled=\(isEnabled)"
        )
        guard isEnabled else {
            throw XCTSkip("Set RUN_LOCAL_SPARKLE_E2E=1 to enable local Sparkle update validation")
        }
        guard appExists && feedExists else {
            throw XCTSkip("Local Sparkle fixtures missing at \(appPath) or \(feedPath)")
        }

        terminateRunningOpenPasteIfNeeded()
        try launchInstalledApp(at: URL(fileURLWithPath: appPath))

        XCTAssertTrue(
            waitForRunningOpenPaste(timeout: 15), "OpenPaste process did not appear for \(appPath)")

        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.activate()

        let appMenu = app.menuBars.menuBarItems["OpenPaste"]
        if appMenu.waitForExistence(timeout: 10) {
            click(appMenu)

            let settingsMenuItem = appMenu.descendants(matching: .menuItem)["Settings…"]
            if settingsMenuItem.waitForExistence(timeout: 5) {
                click(settingsMenuItem)

                let settingsWindow = app.windows.element(boundBy: 0)
                if settingsWindow.waitForExistence(timeout: 10) {
                    let aboutItem = settingsWindow.descendants(matching: .staticText)["About"]
                    if aboutItem.waitForExistence(timeout: 5) {
                        click(aboutItem)
                    }

                    let checkForUpdatesButton = settingsWindow.buttons["Check for Updates…"]
                    if checkForUpdatesButton.waitForExistence(timeout: 5)
                        && checkForUpdatesButton.isEnabled
                    {
                        click(checkForUpdatesButton)
                    }
                }
            }
        }

        let statusCheckForUpdates = app.descendants(matching: .menuItem)["Check for Updates…"]
        if statusCheckForUpdates.waitForExistence(timeout: 5) {
            click(statusCheckForUpdates)
        }

        XCTAssertTrue(
            driveSparkleInstall(in: app, appPath: appPath, expectedVersion: expectedVersion),
            "Expected installed version \(expectedVersion) at \(appPath) after Sparkle update"
        )
    }

    private func launchInstalledApp(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-na", url.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "OpenPasteUITests",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to launch \(url.path) via /usr/bin/open"
                ]
            )
        }
    }

    private func terminateRunningOpenPasteIfNeeded() {
        var running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard !running.isEmpty else { return }

        for app in running {
            app.terminate()
        }

        let deadline = Date().addingTimeInterval(6)
        while Date() < deadline {
            running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if running.isEmpty { return }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }

        for app in running {
            _ = app.forceTerminate()
            _ = kill(pid_t(app.processIdentifier), SIGKILL)
        }
    }

    private func waitForRunningOpenPaste(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }

        return false
    }

    private func click(_ element: XCUIElement) {
        if element.isHittable {
            element.click()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        }
    }

    private func driveSparkleInstall(
        in app: XCUIApplication, appPath: String, expectedVersion: String
    ) -> Bool {
        let buttonTitles = [
            "Install Update", "Install and Relaunch", "Install", "Relaunch", "Relaunch Now",
        ]
        let start = Date()
        let deadline = start.addingTimeInterval(180)
        var requestedAutomaticInstall = false

        while Date() < deadline {
            if installedVersion(at: appPath) == expectedVersion {
                return true
            }

            if let button = firstExistingButton(in: app, titles: buttonTitles) {
                button.click()
            }

            if !requestedAutomaticInstall && Date().timeIntervalSince(start) > 25 {
                print("LocalSparkleDebug requesting automatic install by terminating app")
                terminateRunningOpenPasteIfNeeded()
                requestedAutomaticInstall = true
            }

            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.5))
        }

        return installedVersion(at: appPath) == expectedVersion
    }

    private func firstExistingButton(in app: XCUIApplication, titles: [String]) -> XCUIElement? {
        let buttons = app.descendants(matching: .button)

        for title in titles {
            let button = buttons[title]
            if button.exists {
                return button
            }
        }

        return nil
    }

    private func installedVersion(at appPath: String) -> String? {
        guard
            let info = NSDictionary(contentsOfFile: appPath + "/Contents/Info.plist")
                as? [String: Any]
        else {
            return nil
        }

        return info["CFBundleVersion"] as? String
    }
}
