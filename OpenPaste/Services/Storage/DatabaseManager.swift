import Darwin
import Foundation
import GRDB

actor DatabaseManager {
    nonisolated let dbQueue: DatabaseQueue
    nonisolated let databaseFileURL: URL
    nonisolated let encryptionMarkerURL: URL
    private let syncChangeTracker = SyncChangeTracker()
    private static let dbFileName = "clipboard.sqlite"
    private static let encryptedDbFileName = "clipboard_encrypted.sqlite"

    init(
        databaseDirectoryOverride: URL? = nil,
        passphraseProvider: (() throws -> String)? = nil
    ) throws {
        let fileManager = FileManager.default

        let dbDirectory: URL
        if let override = databaseDirectoryOverride {
            dbDirectory = override
            try fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)
        } else {
            // Use standard API — macOS automatically resolves to the correct location:
            // - Sandbox ON:  ~/Library/Containers/<bundleId>/Data/Library/Application Support/
            // - Sandbox OFF: ~/Library/Application Support/
            guard
                let appSupportURL = fileManager.urls(
                    for: .applicationSupportDirectory, in: .userDomainMask
                ).first
            else {
                throw CocoaError(
                    .fileNoSuchFile,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Could not locate Application Support directory"
                    ])
            }

            dbDirectory = appSupportURL.appendingPathComponent("OpenPaste", isDirectory: true)
            try fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)

            // One-time migration: copy DB from pre-sandbox legacy path if it exists.
            // Use getpwuid() here ONLY to resolve the real home (bypassing sandbox redirect)
            // so we can locate the legacy directory outside the container.
            let legacyDirectory: URL = {
                let realHome: URL = {
                    if let pw = getpwuid(getuid()),
                        let homePath = String(validatingUTF8: pw.pointee.pw_dir)
                    {
                        return URL(fileURLWithPath: homePath, isDirectory: true)
                    }
                    return fileManager.homeDirectoryForCurrentUser
                }()
                return
                    realHome
                    .appendingPathComponent("Library", isDirectory: true)
                    .appendingPathComponent("Application Support", isDirectory: true)
                    .appendingPathComponent("OpenPaste", isDirectory: true)
            }()

            try Self.copyLegacyDatabaseIfNeeded(
                legacyDirectory: legacyDirectory,
                targetDirectory: dbDirectory,
                fileManager: fileManager
            )
        }

        let dbPath = dbDirectory.appendingPathComponent(Self.dbFileName).path
        databaseFileURL = dbDirectory.appendingPathComponent(Self.dbFileName)
        encryptionMarkerURL = dbDirectory.appendingPathComponent(".encrypted")
        let resolvePassphrase =
            passphraseProvider ?? { try KeychainHelper.shared.getOrCreatePassphrase() }
        let passphrase = try resolvePassphrase()

        var config = Configuration()
        config.prepareDatabase { db in
            try db.usePassphrase(passphrase)
            try db.execute(sql: "PRAGMA journal_mode=WAL")
            try db.execute(sql: "PRAGMA synchronous=NORMAL")
        }

        // Migrate unencrypted DB if needed
        let dbExists = fileManager.fileExists(atPath: dbPath)
        let migrationMarker = encryptionMarkerURL.path

        if dbExists && !fileManager.fileExists(atPath: migrationMarker) {
            if Self.isPlainSQLiteDatabase(atPath: dbPath) {
                let encryptedPath = dbDirectory.appendingPathComponent(Self.encryptedDbFileName)
                    .path
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
            } else {
                // DB already looks encrypted; prevent re-migration loops.
                fileManager.createFile(atPath: migrationMarker, contents: nil)
            }
        }

        dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbQueue)

        if !fileManager.fileExists(atPath: migrationMarker) {
            fileManager.createFile(atPath: migrationMarker, contents: nil)
        }

        dbQueue.add(transactionObserver: syncChangeTracker)
    }

    func withSyncTrackingSuspended<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        syncChangeTracker.suspend()
        defer { syncChangeTracker.resume() }
        return try await operation()
    }

    nonisolated func setSyncOutboxCallback(_ callback: @escaping (_ recordNames: [String]) -> Void)
    {
        syncChangeTracker.onOutboxEnqueued = callback
    }

    /// Purge soft-deleted rows, run VACUUM to reclaim disk space, then optimize query planner.
    func vacuum() async throws {
        try await dbQueue.write { db in
            // Hard-delete soft-deleted items and their sync metadata
            try db.execute(
                sql: """
                    DELETE FROM sync_metadata
                    WHERE localId IN (SELECT id FROM clipboardItems WHERE isDeleted = 1)
                    """)
            try db.execute(sql: "DELETE FROM clipboardItems WHERE isDeleted = 1")

            // Hard-delete soft-deleted collections
            try db.execute(
                sql: """
                    DELETE FROM sync_metadata
                    WHERE localId IN (SELECT id FROM collections WHERE isDeleted = 1)
                    """)
            try db.execute(sql: "DELETE FROM collections WHERE isDeleted = 1")

            // Hard-delete soft-deleted smart lists
            try db.execute(
                sql: """
                    DELETE FROM sync_metadata
                    WHERE localId IN (SELECT id FROM smartLists WHERE isDeleted = 1)
                    """)
            try db.execute(sql: "DELETE FROM smartLists WHERE isDeleted = 1")
        }

        // VACUUM must run outside a transaction — it rebuilds the entire DB and resets WAL
        try await dbQueue.vacuum()

        // Update query planner statistics after the rebuild
        try await dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA optimize")
        }
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
        if fileManager.fileExists(atPath: legacyWal.path) {
            try fileManager.copyItem(at: legacyWal, to: targetWal)
        }
        if fileManager.fileExists(atPath: legacyShm.path) {
            try fileManager.copyItem(at: legacyShm, to: targetShm)
        }

        // Preserve encryption migration marker if it exists.
        let legacyMarker = legacyDirectory.appendingPathComponent(".encrypted")
        let targetMarker = targetDirectory.appendingPathComponent(".encrypted")
        if fileManager.fileExists(atPath: legacyMarker.path),
            !fileManager.fileExists(atPath: targetMarker.path)
        {
            try? fileManager.copyItem(at: legacyMarker, to: targetMarker)
        }
    }

    private static func isPlainSQLiteDatabase(atPath path: String) -> Bool {
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe]),
            data.count >= 16
        else { return false }

        let magic = Data("SQLite format 3\u{0}".utf8)
        return data.prefix(16) == magic
    }

    /// Migrate an unencrypted database to SQLCipher-encrypted format
    private static func migrateToEncrypted(
        unencryptedPath: String,
        encryptedPath: String,
        passphrase: String
    ) throws {
        let source = try DatabaseQueue(path: unencryptedPath)
        try source.writeWithoutTransaction { db in
            try db.execute(
                sql: "ATTACH DATABASE ? AS encrypted KEY ?",
                arguments: [encryptedPath, passphrase]
            )
            try db.execute(sql: "SELECT sqlcipher_export('encrypted')")
            try db.execute(sql: "DETACH DATABASE encrypted")
        }
    }
}
