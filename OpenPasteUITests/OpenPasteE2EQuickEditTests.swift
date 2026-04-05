import AppKit
import Darwin
import XCTest

final class OpenPasteE2EQuickEditTests: XCTestCase {
    private let bundleID = "dev.tuanle.OpenPaste"

    override func setUpWithError() throws {
        continueAfterFailure = false

        terminateRunningOpenPasteIfNeeded()
    }

    @MainActor
    func testE2E_QuickEditImage_ExportsResizedTIFFToPasteboard() throws {
        // Ensure we can detect the pasteboard update.
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("openpaste-uitest", forType: .string)

        let app = XCUIApplication()
        app.launchEnvironment["OPENPASTE_UI_TEST_MODE"] = "1"
        app.launchEnvironment["OPENPASTE_UI_TEST_OPEN_PANEL"] = "1"
        app.launchEnvironment["OPENPASTE_UI_TEST_SEED_IMAGE"] = "1"
        app.launchEnvironment["OPENPASTE_UI_TEST_AUTO_OPEN_QUICK_EDIT"] = "1"
        app.launchEnvironment["OPENPASTE_UI_TEST_IMAGE_SCALE"] = "0.25"
        app.launch()
        app.activate()
        defer { app.terminate() }

        // Quick Edit sheet should appear automatically.
        XCTAssertTrue(
            app.staticTexts["Edit before pasting"].waitForExistence(timeout: 10),
            "Expected Quick Edit sheet to open in UI test mode"
        )

        let pasteButton = app.buttons["quickEdit.pasteButton"]
        XCTAssertTrue(pasteButton.waitForExistence(timeout: 5))
        let initialChangeCount = pasteboard.changeCount
        pasteButton.click()

        // Verify we got a TIFF of the expected resized pixel dimensions.
        let expectedWidth = 20
        let expectedHeight = 15

        let deadline = Date().addingTimeInterval(2)
        var tiffData: Data?
        while Date() < deadline {
            if pasteboard.changeCount > initialChangeCount {
                tiffData = pasteboard.data(forType: .tiff)
                if tiffData != nil { break }
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        guard let tiffData else {
            XCTFail("Expected TIFF data on pasteboard after Quick Edit paste")
            return
        }

        let size = try pixelSizeOfTIFF(tiffData)
        XCTAssertEqual(Int(size.width.rounded()), expectedWidth)
        XCTAssertEqual(Int(size.height.rounded()), expectedHeight)
    }

    private func pixelSizeOfTIFF(_ data: Data) throws -> CGSize {
        guard let image = NSImage(data: data) else {
            throw NSError(
                domain: "OpenPasteE2E",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to decode TIFF into NSImage"]
            )
        }

        var rect = CGRect(origin: .zero, size: .zero)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw NSError(
                domain: "OpenPasteE2E",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to read CGImage from NSImage"]
            )
        }

        return CGSize(width: cgImage.width, height: cgImage.height)
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

        // Avoid SIGKILL here: it can confuse XCUITest's lifecycle and produce
        // "Failed to terminate" errors. If termination fails, let the next test
        // handle cleanup and report diagnostics.
    }
}
