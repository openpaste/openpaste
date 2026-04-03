import Foundation

enum CloudKitMapperPayloads {
    struct ClipboardItemPayload: Codable, Sendable {
        var type: String
        var content: Data
        var plainTextContent: String?
        var ocrText: String?
        var sourceAppBundleId: String
        var sourceAppName: String
        var sourceAppIconPath: String?
        var sourceURL: String?
        var tags: String
        var pinned: Bool
        var starred: Bool
        var collectionId: String?
        var contentHash: String
        var isSensitive: Bool
        var expiresAt: Date?
        var metadata: String
    }

    struct CollectionPayload: Codable, Sendable {
        var name: String
        var color: String
    }
}
