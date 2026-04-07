import Foundation

/// Lightweight model for list/grid display — does NOT contain the content `Data` blob.
/// Use `StorageServiceProtocol.fetchContent(for:)` to load content on-demand.
struct ClipboardItemSummary: Identifiable, Sendable, Hashable {
    var id: UUID
    var type: ContentType
    var plainTextContent: String?
    var ocrText: String?
    var sourceApp: AppInfo
    var sourceURL: URL?
    var createdAt: Date
    var modifiedAt: Date
    var pinned: Bool
    var starred: Bool
    var collectionId: UUID?
    var isSensitive: Bool
    var tags: [String]
    var metadata: [String: String]
    var contentHash: String
    var contentSize: Int
}

extension ClipboardItem {
    func toSummary() -> ClipboardItemSummary {
        ClipboardItemSummary(
            id: id,
            type: type,
            plainTextContent: plainTextContent?.truncated(to: 500),
            ocrText: ocrText,
            sourceApp: sourceApp,
            sourceURL: sourceURL,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            pinned: pinned,
            starred: starred,
            collectionId: collectionId,
            isSensitive: isSensitive,
            tags: tags,
            metadata: metadata,
            contentHash: contentHash,
            contentSize: content.count
        )
    }
}
