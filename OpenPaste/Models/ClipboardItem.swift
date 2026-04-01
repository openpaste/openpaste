import Foundation

struct ClipboardItem: Identifiable, Sendable, Hashable {
    var id: UUID
    var type: ContentType
    var content: Data
    var plainTextContent: String?
    var ocrText: String?
    var sourceApp: AppInfo
    var sourceURL: URL?
    var createdAt: Date
    var accessedAt: Date
    var accessCount: Int
    var tags: [String]
    var pinned: Bool
    var starred: Bool
    var collectionId: UUID?
    var contentHash: String
    var isSensitive: Bool
    var expiresAt: Date?
    var metadata: [String: String]

    init(
        id: UUID = UUID(),
        type: ContentType,
        content: Data,
        plainTextContent: String? = nil,
        ocrText: String? = nil,
        sourceApp: AppInfo = .unknown,
        sourceURL: URL? = nil,
        createdAt: Date = Date(),
        accessedAt: Date = Date(),
        accessCount: Int = 0,
        tags: [String] = [],
        pinned: Bool = false,
        starred: Bool = false,
        collectionId: UUID? = nil,
        contentHash: String = "",
        isSensitive: Bool = false,
        expiresAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.plainTextContent = plainTextContent
        self.ocrText = ocrText
        self.sourceApp = sourceApp
        self.sourceURL = sourceURL
        self.createdAt = createdAt
        self.accessedAt = accessedAt
        self.accessCount = accessCount
        self.tags = tags
        self.pinned = pinned
        self.starred = starred
        self.collectionId = collectionId
        self.contentHash = contentHash
        self.isSensitive = isSensitive
        self.expiresAt = expiresAt
        self.metadata = metadata
    }
}
