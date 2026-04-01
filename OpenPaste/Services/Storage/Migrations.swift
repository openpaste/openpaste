import Foundation
import GRDB

struct DatabaseMigrations: Sendable {
    static func registerMigrations(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_createClipboardItems") { db in
            try db.create(table: "clipboardItems") { t in
                t.column("id", .text).primaryKey()
                t.column("type", .text).notNull()
                t.column("content", .blob).notNull()
                t.column("plainTextContent", .text)
                t.column("ocrText", .text)
                t.column("sourceAppBundleId", .text).notNull().defaults(to: "")
                t.column("sourceAppName", .text).notNull().defaults(to: "Unknown")
                t.column("sourceAppIconPath", .text)
                t.column("sourceURL", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("accessedAt", .datetime).notNull()
                t.column("accessCount", .integer).notNull().defaults(to: 0)
                t.column("tags", .text).notNull().defaults(to: "[]")
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("starred", .boolean).notNull().defaults(to: false)
                t.column("collectionId", .text)
                t.column("contentHash", .text).notNull()
                t.column("isSensitive", .boolean).notNull().defaults(to: false)
                t.column("expiresAt", .datetime)
                t.column("metadata", .text).notNull().defaults(to: "{}")
            }

            try db.create(index: "idx_clipboardItems_createdAt", on: "clipboardItems", columns: ["createdAt"])
            try db.create(index: "idx_clipboardItems_contentHash", on: "clipboardItems", columns: ["contentHash"])
            try db.create(index: "idx_clipboardItems_type", on: "clipboardItems", columns: ["type"])
            try db.create(index: "idx_clipboardItems_pinned", on: "clipboardItems", columns: ["pinned"])
        }

        migrator.registerMigration("v1_createFTS5") { db in
            try db.create(virtualTable: "clipboardItemsFts", using: FTS5()) { t in
                t.synchronize(withTable: "clipboardItems")
                t.column("plainTextContent")
                t.column("ocrText")
                t.column("tags")
                t.column("sourceAppName")
            }
        }
    }
}
