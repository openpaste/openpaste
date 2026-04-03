//
//  OpenPasteUITestsLaunchTests.swift
//  OpenPasteUITests
//
//  Created by Lê Anh Tuấn on 1/4/26.
//

import XCTest
import AppKit
import Darwin

final class OpenPasteUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        let env = ProcessInfo.processInfo.environment
        guard env["RUN_UI_TESTS"] == "1" else {
            throw XCTSkip("Set RUN_UI_TESTS=1 to enable UI launch smoke tests")
        }

        terminateRunningOpenPasteIfNeeded()
    }

    private func terminateRunningOpenPasteIfNeeded() {
        let bundleID = "dev.tuanle.OpenPaste"
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

        // If the app is stuck, force-terminate, then fall back to SIGKILL as a last resort.
        for app in running {
            _ = app.forceTerminate()
        }

        let hardDeadline = Date().addingTimeInterval(3)
        while Date() < hardDeadline {
            running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if running.isEmpty { return }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }

        for app in running {
            let pid = pid_t(app.processIdentifier)
            _ = kill(pid, SIGKILL)
        }

        let killDeadline = Date().addingTimeInterval(3)
        while Date() < killDeadline {
            running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if running.isEmpty { return }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
