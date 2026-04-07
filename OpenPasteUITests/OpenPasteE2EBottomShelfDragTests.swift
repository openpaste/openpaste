import AppKit
import Darwin
import XCTest

final class OpenPasteE2EBottomShelfDragTests: XCTestCase {
    private let bundleID = "dev.tuanle.OpenPaste"

    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateRunningOpenPasteIfNeeded()
    }

    override func tearDownWithError() throws {
        terminateRunningOpenPasteIfNeeded()
    }

    @MainActor
    func testE2E_BottomShelf_ReordersCardsViaDrag() throws {
        let app = launchBottomShelfApp(showShortcutHints: false)
        defer { app.terminate() }

        let alpha = app.buttons["Clipboard item Alpha"]
        let gamma = app.buttons["Clipboard item Gamma"]

        XCTAssertTrue(alpha.waitForExistence(timeout: 5))
        XCTAssertTrue(gamma.waitForExistence(timeout: 5))
        XCTAssertEqual(
            cardLabels(in: app),
            ["Clipboard item Alpha", "Clipboard item Beta", "Clipboard item Gamma"])

        alpha.press(forDuration: 0.5, thenDragTo: gamma)

        XCTAssertTrue(
            waitUntil(timeout: 5) {
                self.cardLabels(in: app) == [
                    "Clipboard item Beta", "Clipboard item Alpha", "Clipboard item Gamma",
                ]
            })
    }

    @MainActor
    func testE2E_BottomShelf_ShowsDragHintWhenEnabled() throws {
        let app = launchBottomShelfApp(showShortcutHints: true)
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["Clipboard item Alpha"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Drag To App"].waitForExistence(timeout: 5))
    }

    private func launchBottomShelfApp(showShortcutHints: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["OPENPASTE_UI_TEST_MODE"] = "1"
        app.launchEnvironment["OPENPASTE_UI_TEST_OPEN_PANEL"] = "1"
        app.launchEnvironment["OPENPASTE_UI_TEST_WINDOW_MODE"] = "bottomShelf"
        app.launchEnvironment["OPENPASTE_UI_TEST_SHOW_SHORTCUT_HINTS"] =
            showShortcutHints ? "1" : "0"
        app.launchEnvironment["OPENPASTE_UI_TEST_SEED_TEXT_ITEMS"] = "Alpha|Beta|Gamma"
        app.launch()
        return app
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }

        return condition()
    }

    private func cardLabels(in app: XCUIApplication) -> [String] {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "bottomShelf.card.")
        return app.descendants(matching: .button)
            .matching(predicate)
            .allElementsBoundByIndex
            .map(\.label)
    }

    private func terminateRunningOpenPasteIfNeeded() {
        forceKillOpenPasteProcess()

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

    private func forceKillOpenPasteProcess() {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            let pid = app.processIdentifier
            let parentPID = parentProcessID(for: pid)
            _ = Darwin.kill(pid, SIGKILL)
            if parentPID > 1 {
                _ = Darwin.kill(parentPID, SIGKILL)
            }
        }
    }

    private func parentProcessID(for pid: pid_t) -> pid_t {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "ppid="]

        let pipe = Pipe()
        process.standardOutput = pipe

        try? process.run()
        process.waitUntilExit()

        let output = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines)

        return pid_t(Int(output ?? "") ?? 0)
    }
}
