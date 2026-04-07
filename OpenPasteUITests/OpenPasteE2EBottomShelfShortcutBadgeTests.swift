import AppKit
import CoreGraphics
import Darwin
import XCTest

final class OpenPasteE2EBottomShelfShortcutBadgeTests: XCTestCase {
    private let bundleID = "dev.tuanle.OpenPaste"
    private let commandKeyCode: CGKeyCode = 0x37

    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateRunningOpenPasteIfNeeded()
    }

    override func tearDownWithError() throws {
        releaseCommandKey()
        terminateRunningOpenPasteIfNeeded()
    }

    @MainActor
    func testE2E_BottomShelf_RevealsShortcutBadgesWhileCommandIsHeld() throws {
        let app = launchBottomShelfApp()
        defer {
            releaseCommandKey()
            app.terminate()
        }

        let alpha = app.buttons["Clipboard item Alpha"]
        let beta = app.buttons["Clipboard item Beta"]
        let gamma = app.buttons["Clipboard item Gamma"]

        XCTAssertTrue(
            alpha.waitForExistence(timeout: 10),
            "Expected Clipboard item Alpha to exist. Accessibility hierarchy:\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            beta.waitForExistence(timeout: 10),
            "Expected Clipboard item Beta to exist. Accessibility hierarchy:\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            gamma.waitForExistence(timeout: 10),
            "Expected Clipboard item Gamma to exist. Accessibility hierarchy:\n\(app.debugDescription)"
        )

        XCTAssertTrue(
            waitUntil(timeout: 2) {
                self.quickIndexValue(for: alpha) == "hidden"
                    && self.quickIndexValue(for: beta) == "hidden"
                    && self.quickIndexValue(for: gamma) == "hidden"
            },
            "Expected quick index badges to start hidden before Command is pressed"
        )

        pressCommandKey()

        XCTAssertTrue(
            waitUntil(timeout: 2) {
                self.quickIndexValue(for: alpha) == "cmd1"
                    && self.quickIndexValue(for: beta) == "cmd2"
                    && self.quickIndexValue(for: gamma) == "cmd3"
            },
            "Expected all visible quick index badges to appear while Command is held"
        )

        releaseCommandKey()

        XCTAssertTrue(
            waitUntil(timeout: 2) {
                self.quickIndexValue(for: alpha) == "hidden"
                    && self.quickIndexValue(for: beta) == "hidden"
                    && self.quickIndexValue(for: gamma) == "hidden"
            },
            "Expected quick index badges to hide again after releasing Command"
        )
    }

    private func launchBottomShelfApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["OPENPASTE_UI_TEST_MODE"] = "1"
        app.launchEnvironment["OPENPASTE_UI_TEST_OPEN_PANEL"] = "1"
        app.launchEnvironment["OPENPASTE_UI_TEST_WINDOW_MODE"] = "bottomShelf"
        app.launchEnvironment["OPENPASTE_UI_TEST_SHOW_SHORTCUT_HINTS"] = "0"
        app.launchEnvironment["OPENPASTE_UI_TEST_SEED_TEXT_ITEMS"] = "Alpha|Beta|Gamma"
        app.launch()
        return app
    }

    private func quickIndexValue(for card: XCUIElement) -> String? {
        card.value as? String
    }

    private func pressCommandKey() {
        postCommandFlagsChanged(isPressed: true)
    }

    private func releaseCommandKey() {
        postCommandFlagsChanged(isPressed: false)
    }

    private func postCommandFlagsChanged(isPressed: Bool) {
        guard let source = CGEventSource(stateID: .hidSystemState),
            let event = CGEvent(source: source)
        else {
            XCTFail("Expected to create a CGEvent for Command modifier synthesis")
            return
        }

        event.type = .flagsChanged
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(commandKeyCode))
        event.flags = isPressed ? .maskCommand : []
        event.post(tap: .cghidEventTap)
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
