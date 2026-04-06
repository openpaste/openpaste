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

        migrator.registerMigration("v2_createCollections") { db in
            try db.create(table: "collections") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v3_addCollectionColor") { db in
            try db.alter(table: "collections") { t in
                t.add(column: "color", .text).notNull().defaults(to: "#007AFF")
            }
        }

        migrator.registerMigration("v4_addSyncSupport") { db in
            // clipboardItems sync fields
            try db.alter(table: "clipboardItems") { t in
                t.add(column: "modifiedAt", .datetime)
                t.add(column: "deviceId", .text).notNull().defaults(to: "")
                t.add(column: "isDeleted", .boolean).notNull().defaults(to: false)
                t.add(column: "syncVersion", .integer).notNull().defaults(to: 0)
            }
            try db.execute(sql: "UPDATE clipboardItems SET modifiedAt = createdAt WHERE modifiedAt IS NULL")

            // collections sync fields
            try db.alter(table: "collections") { t in
                t.add(column: "modifiedAt", .datetime)
                t.add(column: "deviceId", .text).notNull().defaults(to: "")
                t.add(column: "isDeleted", .boolean).notNull().defaults(to: false)
            }
            try db.execute(sql: "UPDATE collections SET modifiedAt = createdAt WHERE modifiedAt IS NULL")

            // outbox for CloudKit sync
            try db.create(table: "sync_metadata", ifNotExists: true) { t in
                t.column("recordName", .text).primaryKey()
                t.column("tableName", .text).notNull()
                t.column("localId", .text).notNull()
                t.column("operation", .text).notNull() // upsert | delete
                t.column("syncStatus", .text).notNull().defaults(to: "pending")
                t.column("lastError", .text)
                t.column("retryCount", .integer).notNull().defaults(to: 0)
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "idx_sync_metadata_status", on: "sync_metadata", columns: ["syncStatus"], ifNotExists: true)
            try db.create(index: "idx_sync_metadata_table", on: "sync_metadata", columns: ["tableName"], ifNotExists: true)

            // persisted CKSyncEngine state (singleton)
            try db.create(table: "sync_engine_state", ifNotExists: true) { t in
                t.column("id", .integer)
                    .notNull()
                    .primaryKey()
                    .check(sql: "id = 1")
                t.column("stateData", .blob).notNull()
                t.column("lastSyncDate", .datetime)
                t.column("deviceId", .text).notNull()
                t.column("keyVersion", .integer).notNull().defaults(to: 1)
            }
        }

        migrator.registerMigration("v5_addCloudKitSystemFields") { db in
            // Store CKRecord system fields for conflict handling.
            try db.alter(table: "clipboardItems") { t in
                t.add(column: "ckSystemFields", .blob)
            }
            try db.alter(table: "collections") { t in
                t.add(column: "ckSystemFields", .blob)
            }
        }

        migrator.registerMigration("v6_addSyncOutboxTriggers") { db in
            // Keep sync_metadata in sync with local mutations.
            // Fail-closed: sensitive items are excluded by default (no backfill for historical sensitive items).
            try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS trg_clipboardItems_sync_insert
            AFTER INSERT ON clipboardItems
            WHEN NEW.isSensitive = 0
            BEGIN
              INSERT INTO sync_metadata (recordName, tableName, localId, operation, syncStatus, retryCount, updatedAt)
              VALUES ('item_' || NEW.id, 'clipboardItems', NEW.id, 'upsert', 'pending', 0, CURRENT_TIMESTAMP)
              ON CONFLICT(recordName) DO UPDATE SET
                tableName = excluded.tableName,
                localId = excluded.localId,
                operation = excluded.operation,
                syncStatus = 'pending',
                lastError = NULL,
                retryCount = 0,
                updatedAt = excluded.updatedAt;
            END;
            """)

            try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS trg_clipboardItems_sync_update
            AFTER UPDATE ON clipboardItems
            WHEN NEW.isSensitive = 0 AND NEW.syncVersion != OLD.syncVersion
            BEGIN
              INSERT INTO sync_metadata (recordName, tableName, localId, operation, syncStatus, retryCount, updatedAt)
              VALUES ('item_' || NEW.id, 'clipboardItems', NEW.id, 'upsert', 'pending', 0, CURRENT_TIMESTAMP)
              ON CONFLICT(recordName) DO UPDATE SET
                operation = excluded.operation,
                syncStatus = 'pending',
                lastError = NULL,
                retryCount = 0,
                updatedAt = excluded.updatedAt;
            END;
            """)

            try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS trg_collections_sync_insert
            AFTER INSERT ON collections
            BEGIN
              INSERT INTO sync_metadata (recordName, tableName, localId, operation, syncStatus, retryCount, updatedAt)
              VALUES ('collection_' || NEW.id, 'collections', NEW.id, 'upsert', 'pending', 0, CURRENT_TIMESTAMP)
              ON CONFLICT(recordName) DO UPDATE SET
                tableName = excluded.tableName,
                localId = excluded.localId,
                operation = excluded.operation,
                syncStatus = 'pending',
                lastError = NULL,
                retryCount = 0,
                updatedAt = excluded.updatedAt;
            END;
            """)

            try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS trg_collections_sync_update
            AFTER UPDATE ON collections
            WHEN NEW.modifiedAt != OLD.modifiedAt OR NEW.isDeleted != OLD.isDeleted
            BEGIN
              INSERT INTO sync_metadata (recordName, tableName, localId, operation, syncStatus, retryCount, updatedAt)
              VALUES ('collection_' || NEW.id, 'collections', NEW.id, 'upsert', 'pending', 0, CURRENT_TIMESTAMP)
              ON CONFLICT(recordName) DO UPDATE SET
                operation = excluded.operation,
                syncStatus = 'pending',
                lastError = NULL,
                retryCount = 0,
                updatedAt = excluded.updatedAt;
            END;
            """)
        }

        migrator.registerMigration("v7_removeSyncOutboxTriggers") { db in
            // Replaced by SyncChangeTracker (GRDB TransactionObserver).
            // Triggers can't support remote-apply loop suppression or opt-in sensitive sync.
            try db.execute(sql: "DROP TRIGGER IF EXISTS trg_clipboardItems_sync_insert")
            try db.execute(sql: "DROP TRIGGER IF EXISTS trg_clipboardItems_sync_update")
            try db.execute(sql: "DROP TRIGGER IF EXISTS trg_collections_sync_insert")
            try db.execute(sql: "DROP TRIGGER IF EXISTS trg_collections_sync_update")
        }

        migrator.registerMigration("v8_createSmartLists") { db in
            try db.create(table: "smartLists") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("icon", .text).notNull().defaults(to: "list.bullet")
                t.column("color", .text).notNull().defaults(to: "#007AFF")
                t.column("rules", .text).notNull().defaults(to: "[]")
                t.column("matchMode", .text).notNull().defaults(to: "all")
                t.column("sortOrder", .text).notNull().defaults(to: "newestFirst")
                t.column("isBuiltIn", .boolean).notNull().defaults(to: false)
                t.column("position", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
                t.column("modifiedAt", .datetime).notNull()
                t.column("deviceId", .text).notNull().defaults(to: "")
                t.column("isDeleted", .boolean).notNull().defaults(to: false)
                t.column("ckSystemFields", .blob)
            }
        }
    }
}
