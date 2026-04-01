import Foundation
import GRDB
@testable import OpenPaste

enum TestHelpers {
    static func makeInMemoryDatabaseQueue() throws -> DatabaseQueue {
        let dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbQueue)
        return dbQueue
    }

    static func makeTextItem(
        text: String = "test text",
        sourceApp: AppInfo = .unknown,
        tags: [String] = [],
        pinned: Bool = false,
        starred: Bool = false,
        isSensitive: Bool = false,
        collectionId: UUID? = nil,
        expiresAt: Date? = nil
    ) -> ClipboardItem {
        ClipboardItem(
            type: .text,
            content: Data(text.utf8),
            plainTextContent: text,
            sourceApp: sourceApp,
            tags: tags,
            pinned: pinned,
            starred: starred,
            collectionId: collectionId,
            contentHash: ContentHasher().hash(Data(text.utf8)),
            isSensitive: isSensitive,
            expiresAt: expiresAt
        )
    }

    static func makeImageItem(
        data: Data = Data([0x89, 0x50, 0x4E, 0x47]),
        sourceApp: AppInfo = .unknown
    ) -> ClipboardItem {
        ClipboardItem(
            type: .image,
            content: data,
            sourceApp: sourceApp,
            contentHash: ContentHasher().hash(data)
        )
    }

    static func makeCodeItem(text: String = "func hello() { }") -> ClipboardItem {
        ClipboardItem(
            type: .code,
            content: Data(text.utf8),
            plainTextContent: text,
            contentHash: ContentHasher().hash(Data(text.utf8))
        )
    }
}
