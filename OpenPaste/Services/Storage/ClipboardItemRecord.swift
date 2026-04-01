import Foundation
@preconcurrency import GRDB

struct ClipboardItemRecord: Sendable, Hashable, Identifiable {
    var id: String
    var type: String
    var content: Data
    var plainTextContent: String?
    var ocrText: String?
    var sourceAppBundleId: String
    var sourceAppName: String
    var sourceAppIconPath: String?
    var sourceURL: String?
    var createdAt: Date
    var accessedAt: Date
    var accessCount: Int
    var tags: String
    var pinned: Bool
    var starred: Bool
    var collectionId: String?
    var contentHash: String
    var isSensitive: Bool
    var expiresAt: Date?
    var metadata: String
}

extension ClipboardItemRecord: FetchableRecord {
    nonisolated static var databaseTableName: String { "clipboardItems" }

    nonisolated init(row: Row) {
        id = row["id"]
        type = row["type"]
        content = row["content"]
        plainTextContent = row["plainTextContent"]
        ocrText = row["ocrText"]
        sourceAppBundleId = row["sourceAppBundleId"]
        sourceAppName = row["sourceAppName"]
        sourceAppIconPath = row["sourceAppIconPath"]
        sourceURL = row["sourceURL"]
        createdAt = row["createdAt"]
        accessedAt = row["accessedAt"]
        accessCount = row["accessCount"]
        tags = row["tags"]
        pinned = row["pinned"]
        starred = row["starred"]
        collectionId = row["collectionId"]
        contentHash = row["contentHash"]
        isSensitive = row["isSensitive"]
        expiresAt = row["expiresAt"]
        metadata = row["metadata"]
    }
}

extension ClipboardItemRecord: PersistableRecord {
    nonisolated func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["type"] = type
        container["content"] = content
        container["plainTextContent"] = plainTextContent
        container["ocrText"] = ocrText
        container["sourceAppBundleId"] = sourceAppBundleId
        container["sourceAppName"] = sourceAppName
        container["sourceAppIconPath"] = sourceAppIconPath
        container["sourceURL"] = sourceURL
        container["createdAt"] = createdAt
        container["accessedAt"] = accessedAt
        container["accessCount"] = accessCount
        container["tags"] = tags
        container["pinned"] = pinned
        container["starred"] = starred
        container["collectionId"] = collectionId
        container["contentHash"] = contentHash
        container["isSensitive"] = isSensitive
        container["expiresAt"] = expiresAt
        container["metadata"] = metadata
    }
}

extension ClipboardItemRecord {
    init(from item: ClipboardItem) {
        self.id = item.id.uuidString
        self.type = item.type.rawValue
        self.content = item.content
        self.plainTextContent = item.plainTextContent
        self.ocrText = item.ocrText
        self.sourceAppBundleId = item.sourceApp.bundleId
        self.sourceAppName = item.sourceApp.name
        self.sourceAppIconPath = item.sourceApp.iconPath
        self.sourceURL = item.sourceURL?.absoluteString
        self.createdAt = item.createdAt
        self.accessedAt = item.accessedAt
        self.accessCount = item.accessCount
        self.tags = (try? JSONEncoder().encode(item.tags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.pinned = item.pinned
        self.starred = item.starred
        self.collectionId = item.collectionId?.uuidString
        self.contentHash = item.contentHash
        self.isSensitive = item.isSensitive
        self.expiresAt = item.expiresAt
        self.metadata = (try? JSONEncoder().encode(item.metadata)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    func toClipboardItem() -> ClipboardItem {
        let decodedTags = (try? JSONDecoder().decode([String].self, from: Data(tags.utf8))) ?? []
        let decodedMetadata = (try? JSONDecoder().decode([String: String].self, from: Data(metadata.utf8))) ?? [:]

        return ClipboardItem(
            id: UUID(uuidString: id) ?? UUID(),
            type: ContentType(rawValue: type) ?? .text,
            content: content,
            plainTextContent: plainTextContent,
            ocrText: ocrText,
            sourceApp: AppInfo(bundleId: sourceAppBundleId, name: sourceAppName, iconPath: sourceAppIconPath),
            sourceURL: sourceURL.flatMap { URL(string: $0) },
            createdAt: createdAt,
            accessedAt: accessedAt,
            accessCount: accessCount,
            tags: decodedTags,
            pinned: pinned,
            starred: starred,
            collectionId: collectionId.flatMap { UUID(uuidString: $0) },
            contentHash: contentHash,
            isSensitive: isSensitive,
            expiresAt: expiresAt,
            metadata: decodedMetadata
        )
    }
}
