import AppKit
import Foundation
import XCTest

final class OpenPasteE2ESQLCipherTests: XCTestCase {
    private struct SQLCipherDiagnostics: Decodable {
        let databasePath: String?
        let markerPath: String?
        let dbExists: Bool
        let markerExists: Bool
        let headerBase64: String?
        let initError: String?
    }

    private let bundleID = "dev.tuanle.OpenPaste"

    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateRunningOpenPasteIfNeeded()
    }

    func testE2E_SQLCipherDatabaseIsEncryptedAtRest() throws {
        let relativeDir = "OpenPasteUITests/sqlcipher-\(UUID().uuidString)"
        let pasteboardName = NSPasteboard.Name(
            "dev.tuanle.OpenPaste.uitest.sqlcipher.\(UUID().uuidString)")
        let diagnosticsPasteboard = NSPasteboard(name: pasteboardName)
        diagnosticsPasteboard.clearContents()

        let app = XCUIApplication()
        app.launchEnvironment["OPENPASTE_UI_TEST_MODE"] = "1"
        app.launchEnvironment["OPENPASTE_UI_TEST_DATABASE_DIR"] = relativeDir
        app.launchEnvironment["OPENPASTE_UI_TEST_SQLCIPHER_PASTEBOARD"] = pasteboardName.rawValue
        app.launch()
        app.activate()
        defer { app.terminate() }

        let diagnostics = try waitForDiagnostics(from: diagnosticsPasteboard, timeout: 20)

        XCTAssertNil(
            diagnostics.initError, "App init failed: \(diagnostics.initError ?? "unknown")")
        XCTAssertTrue(
            diagnostics.dbExists, "Expected UI-test diagnostics to report clipboard.sqlite creation"
        )
        XCTAssertTrue(
            diagnostics.markerExists,
            "Expected UI-test diagnostics to report .encrypted marker creation")
        XCTAssertEqual(diagnostics.databasePath?.contains(relativeDir), true)
        XCTAssertEqual(diagnostics.markerPath?.contains(relativeDir), true)
        XCTAssertEqual(diagnostics.databasePath?.hasSuffix("clipboard.sqlite"), true)
        XCTAssertEqual(diagnostics.markerPath?.hasSuffix(".encrypted"), true)

        let headerData = try XCTUnwrap(
            diagnostics.headerBase64.flatMap { Data(base64Encoded: $0) },
            "Expected SQLCipher diagnostics header data"
        )
        let sqliteMagic = Data("SQLite format 3\u{0}".utf8)

        XCTAssertGreaterThanOrEqual(headerData.count, sqliteMagic.count)
        XCTAssertNotEqual(
            Data(headerData.prefix(sqliteMagic.count)),
            sqliteMagic,
            "Expected encrypted DB header, not plain SQLite"
        )
    }

    private func waitForDiagnostics(from pasteboard: NSPasteboard, timeout: TimeInterval) throws
        -> SQLCipherDiagnostics
    {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let json = pasteboard.string(forType: .string),
                let data = json.data(using: .utf8),
                let diagnostics = try? JSONDecoder().decode(SQLCipherDiagnostics.self, from: data)
            {
                return diagnostics
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        throw NSError(
            domain: "OpenPasteE2E",
            code: 3,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Timed out waiting for SQLCipher diagnostics on pasteboard \(pasteboard.name.rawValue)"
            ]
        )
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
