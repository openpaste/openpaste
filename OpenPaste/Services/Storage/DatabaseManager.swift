import Foundation
import GRDB

actor DatabaseManager {
    nonisolated let dbQueue: DatabaseQueue
    private let syncChangeTracker = SyncChangeTracker()
    private static let dbFileName = "clipboard.sqlite"
    private static let encryptedDbFileName = "clipboard_encrypted.sqlite"

    init() throws {
        let fileManager = FileManager.default

        // Prefer a sandbox-compatible location so enabling App Sandbox later doesn't reset user data.
        // - Legacy (pre-sandbox): ~/Library/Application Support/OpenPaste/
        // - Sandbox: ~/Library/Containers/<bundleId>/Data/Library/Application Support/OpenPaste/
        // NOTE: We compute the legacy path explicitly so it remains correct even when App Sandbox is enabled
        // (where `.applicationSupportDirectory` resolves inside the app container).
        let legacyDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("OpenPaste", isDirectory: true)

        let bundleId = Bundle.main.bundleIdentifier ?? "dev.tuanle.OpenPaste"
        let preferredAppSupportURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent(bundleId, isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        let dbDirectory = preferredAppSupportURL.appendingPathComponent("OpenPaste", isDirectory: true)
        try fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)

        try Self.copyLegacyDatabaseIfNeeded(
            legacyDirectory: legacyDirectory,
            targetDirectory: dbDirectory,
            fileManager: fileManager
        )

        let dbPath = dbDirectory.appendingPathComponent(Self.dbFileName).path

        #if GRDBCIPHER
        let passphrase = try KeychainHelper.shared.getOrCreatePassphrase()
        #endif

        var config = Configuration()
        config.prepareDatabase { db in
            #if GRDBCIPHER
            try db.usePassphrase(passphrase)
            #endif
            try db.execute(sql: "PRAGMA journal_mode=WAL")
            try db.execute(sql: "PRAGMA synchronous=NORMAL")
        }

        // Migrate unencrypted DB if needed
        let unencryptedExists = fileManager.fileExists(atPath: dbPath)
        let migrationMarker = dbDirectory.appendingPathComponent(".encrypted").path

        #if GRDBCIPHER
        if unencryptedExists && !fileManager.fileExists(atPath: migrationMarker) {
            let encryptedPath = dbDirectory.appendingPathComponent(Self.encryptedDbFileName).path
            try Self.migrateToEncrypted(
                unencryptedPath: dbPath,
                encryptedPath: encryptedPath,
                passphrase: passphrase
            )
            // Atomic replacement: backup original, move encrypted, then cleanup
            let backupPath = dbPath + ".bak"
            try fileManager.moveItem(atPath: dbPath, toPath: backupPath)
            try fileManager.moveItem(atPath: encryptedPath, toPath: dbPath)
            try? fileManager.removeItem(atPath: backupPath)
            fileManager.createFile(atPath: migrationMarker, contents: nil)
        }
        #endif

        dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbQueue)

        dbQueue.add(transactionObserver: syncChangeTracker)
    }

    func withSyncTrackingSuspended<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        syncChangeTracker.suspend()
        defer { syncChangeTracker.resume() }
        return try await operation()
    }

    nonisolated func setSyncOutboxCallback(_ callback: @escaping (_ recordNames: [String]) -> Void) {
        syncChangeTracker.onOutboxEnqueued = callback
    }

    private static func copyLegacyDatabaseIfNeeded(
        legacyDirectory: URL,
        targetDirectory: URL,
        fileManager: FileManager
    ) throws {
        let legacyDB = legacyDirectory.appendingPathComponent(Self.dbFileName)
        let targetDB = targetDirectory.appendingPathComponent(Self.dbFileName)

        guard fileManager.fileExists(atPath: legacyDB.path),
              !fileManager.fileExists(atPath: targetDB.path)
        else { return }

        // Copy main DB and WAL/SHM if present (WAL mode).
        let legacyWal = URL(fileURLWithPath: legacyDB.path + "-wal")
        let legacyShm = URL(fileURLWithPath: legacyDB.path + "-shm")
        let targetWal = URL(fileURLWithPath: targetDB.path + "-wal")
        let targetShm = URL(fileURLWithPath: targetDB.path + "-shm")

        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        try fileManager.copyItem(at: legacyDB, to: targetDB)
        if fileManager.fileExists(atPath: legacyWal.path) { try fileManager.copyItem(at: legacyWal, to: targetWal) }
        if fileManager.fileExists(atPath: legacyShm.path) { try fileManager.copyItem(at: legacyShm, to: targetShm) }

        // Preserve encryption migration marker if it exists.
        let legacyMarker = legacyDirectory.appendingPathComponent(".encrypted")
        let targetMarker = targetDirectory.appendingPathComponent(".encrypted")
        if fileManager.fileExists(atPath: legacyMarker.path), !fileManager.fileExists(atPath: targetMarker.path) {
            try? fileManager.copyItem(at: legacyMarker, to: targetMarker)
        }
    }

    #if GRDBCIPHER
    /// Migrate an unencrypted database to SQLCipher-encrypted format
    private static func migrateToEncrypted(
        unencryptedPath: String,
        encryptedPath: String,
        passphrase: String
    ) throws {
        let source = try DatabaseQueue(path: unencryptedPath)
        try source.write { db in
            try db.execute(
                sql: "ATTACH DATABASE ? AS encrypted KEY ?",
                arguments: [encryptedPath, passphrase]
            )
            try db.execute(sql: "SELECT sqlcipher_export('encrypted')")
            try db.execute(sql: "DETACH DATABASE encrypted")
        }
    }
    #endif
}
