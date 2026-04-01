import Foundation
import GRDB

actor DatabaseManager {
    let dbQueue: DatabaseQueue
    private static let dbFileName = "clipboard.sqlite"
    private static let encryptedDbFileName = "clipboard_encrypted.sqlite"

    init() throws {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbDirectory = appSupportURL.appendingPathComponent("OpenPaste", isDirectory: true)
        try fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)
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
