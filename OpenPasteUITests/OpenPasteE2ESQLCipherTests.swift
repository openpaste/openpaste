import AppKit
import Darwin
import XCTest

final class OpenPasteE2ESQLCipherTests: XCTestCase {
    private let bundleID = "dev.tuanle.OpenPaste"

    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateRunningOpenPasteIfNeeded()
    }

    func testE2E_SQLCipherDatabaseIsEncryptedAtRest() throws {
        let relativeDir = "OpenPasteUITests/sqlcipher-\(UUID().uuidString)"

        let app = XCUIApplication()
        app.launchEnvironment["OPENPASTE_UI_TEST_MODE"] = "1"
        app.launchEnvironment["OPENPASTE_UI_TEST_DATABASE_DIR"] = relativeDir
        app.launchEnvironment["OPENPASTE_UI_TEST_SEED_IMAGE"] = "1"
        app.launch()
        app.activate()
        defer { app.terminate() }

        let containerTmp = realHomeDirectory()
            .appendingPathComponent("Library/Containers/\(bundleID)/Data/tmp", isDirectory: true)
        let runDir = URL(fileURLWithPath: relativeDir, isDirectory: true, relativeTo: containerTmp)
            .standardizedFileURL

        let dbURL = runDir.appendingPathComponent("clipboard.sqlite")
        let markerURL = runDir.appendingPathComponent(".encrypted")

        XCTAssertTrue(waitForFileReady(dbURL, minBytes: 16, timeout: 20), "Expected clipboard.sqlite to be created")
        XCTAssertTrue(waitForFile(markerURL, timeout: 20), "Expected .encrypted marker to be created")

        let data = try Data(contentsOf: dbURL, options: [.mappedIfSafe])
        XCTAssertGreaterThanOrEqual(data.count, 16)

        let sqliteMagic = Data("SQLite format 3\u{0}".utf8)
        XCTAssertNotEqual(data.prefix(16), sqliteMagic, "Expected encrypted DB header (not plain SQLite)")
    }

    private func realHomeDirectory() -> URL {
        if let pw = getpwuid(getuid()),
           let homePath = String(validatingUTF8: pw.pointee.pw_dir) {
            return URL(fileURLWithPath: homePath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private func waitForFile(_ url: URL, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return false
    }

    private func waitForFileReady(_ url: URL, minBytes: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? NSNumber,
               size.intValue >= minBytes {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return false
    }

    private func terminateRunningOpenPasteIfNeeded() {
        var running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard !running.isEmpty else { return }

        for app in running { app.terminate() }

        let softDeadline = Date().addingTimeInterval(3)
        while Date() < softDeadline {
            running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if running.isEmpty { return }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }

        for app in running { _ = app.forceTerminate() }
    }
}
