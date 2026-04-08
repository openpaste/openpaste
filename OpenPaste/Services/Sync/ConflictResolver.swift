import Foundation

enum ConflictResolver {
    static func resolve(local: ClipboardItemRecord, remote: ClipboardItemRecord)
        -> ClipboardItemRecord
    {
        let remoteWins = remote.modifiedAt >= local.modifiedAt
        var merged = remoteWins ? remote : local

        // Fields with LWW semantics
        if remoteWins {
            merged.content = remote.content
            merged.plainTextContent = remote.plainTextContent
            merged.ocrText = remote.ocrText
            merged.sourceAppBundleId = remote.sourceAppBundleId
            merged.sourceAppName = remote.sourceAppName
            merged.sourceAppIconPath = remote.sourceAppIconPath
            merged.sourceURL = remote.sourceURL
            merged.collectionId = remote.collectionId
            merged.expiresAt = remote.expiresAt
            merged.contentHash = remote.contentHash
            merged.isSensitive = remote.isSensitive
            merged.deviceId = remote.deviceId
            merged.isDeleted = remote.isDeleted
        }

        // Tags: set union
        merged.tags = encodeTags(union: decodeTags(local.tags), decodeTags(remote.tags))

        // Booleans: LWW (the most recently modified device decides)
        merged.pinned = remoteWins ? remote.pinned : local.pinned
        merged.starred = remoteWins ? remote.starred : local.starred

        // Counters: max
        merged.accessCount = max(local.accessCount, remote.accessCount)
        merged.accessedAt = max(local.accessedAt, remote.accessedAt)

        // Metadata: dictionary merge (prefer winner)
        merged.metadata = encodeMetadata(
            merge: decodeMetadata(local.metadata), decodeMetadata(remote.metadata),
            preferRemote: remoteWins)

        // Timestamps/versions
        merged.modifiedAt = max(local.modifiedAt, remote.modifiedAt)
        merged.syncVersion = max(local.syncVersion, remote.syncVersion)

        return merged
    }

    static func resolve(local: CollectionRecord, remote: CollectionRecord) -> CollectionRecord {
        let remoteWins = remote.modifiedAt >= local.modifiedAt
        var merged = remoteWins ? remote : local

        if remoteWins {
            merged.name = remote.name
            merged.color = remote.color
            merged.deviceId = remote.deviceId
            merged.isDeleted = remote.isDeleted
        }

        merged.modifiedAt = max(local.modifiedAt, remote.modifiedAt)
        return merged
    }

    private static func decodeTags(_ json: String) -> Set<String> {
        (try? JSONDecoder().decode([String].self, from: Data(json.utf8))).map(Set.init) ?? []
    }

    private static func encodeTags(union a: Set<String>, _ b: Set<String>) -> String {
        let merged = Array(a.union(b)).sorted()
        let data = (try? JSONEncoder().encode(merged)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func decodeMetadata(_ json: String) -> [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(json.utf8))) ?? [:]
    }

    private static func encodeMetadata(
        merge local: [String: String],
        _ remote: [String: String],
        preferRemote: Bool
    ) -> String {
        var merged = local
        for (k, v) in remote {
            if merged[k] == nil || preferRemote {
                merged[k] = v
            }
        }
        let data = (try? JSONEncoder().encode(merged)) ?? Data("{}".utf8)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
