import Foundation
@preconcurrency import CloudKit

enum CloudKitMapperDecodeError: Error {
    case missingField(String)
    case missingAsset
}

extension CloudKitMapper {
    static func decodeClipboardItem(
        from record: CKRecord,
        encryption: SyncEncryptionServiceProtocol
    ) throws -> ClipboardItemRecord {
        guard let localId = record[Field.localId] as? String else {
            throw CloudKitMapperDecodeError.missingField(Field.localId)
        }

        let createdAt = record[Field.createdAt] as? Date ?? Date()
        let modifiedAt = record[Field.modifiedAt] as? Date ?? createdAt
        let deviceId = record[Field.deviceId] as? String ?? ""
        let isDeleted = record[Field.isDeleted] as? Bool ?? false
        let syncVersion = record[Field.syncVersion] as? Int ?? 0
        let keyVersion = record[Field.payloadKeyVersion] as? Int ?? 1

        guard let asset = record[Field.payloadAsset] as? CKAsset,
              let url = asset.fileURL else {
            throw CloudKitMapperDecodeError.missingAsset
        }

        let encrypted = try Data(contentsOf: url)
        let json = try encryption.decrypt(encrypted, keyVersion: keyVersion)
        let payload = try JSONDecoder().decode(CloudKitMapperPayloads.ClipboardItemPayload.self, from: json)

        return ClipboardItemRecord(
            id: localId,
            type: payload.type,
            content: payload.content,
            plainTextContent: payload.plainTextContent,
            ocrText: payload.ocrText,
            sourceAppBundleId: payload.sourceAppBundleId,
            sourceAppName: payload.sourceAppName,
            sourceAppIconPath: payload.sourceAppIconPath,
            sourceURL: payload.sourceURL,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            deviceId: deviceId,
            isDeleted: isDeleted,
            syncVersion: syncVersion,
            ckSystemFields: nil,
            accessedAt: createdAt,
            accessCount: 0,
            tags: payload.tags,
            pinned: payload.pinned,
            starred: payload.starred,
            collectionId: payload.collectionId,
            contentHash: payload.contentHash,
            isSensitive: payload.isSensitive,
            expiresAt: payload.expiresAt,
            metadata: payload.metadata
        )
    }

    static func decodeCollection(
        from record: CKRecord,
        encryption: SyncEncryptionServiceProtocol
    ) throws -> CollectionRecord {
        guard let localId = record[Field.localId] as? String else {
            throw CloudKitMapperDecodeError.missingField(Field.localId)
        }

        let createdAt = record[Field.createdAt] as? Date ?? Date()
        let modifiedAt = record[Field.modifiedAt] as? Date ?? createdAt
        let deviceId = record[Field.deviceId] as? String ?? ""
        let isDeleted = record[Field.isDeleted] as? Bool ?? false
        let keyVersion = record[Field.payloadKeyVersion] as? Int ?? 1

        guard let asset = record[Field.payloadAsset] as? CKAsset,
              let url = asset.fileURL else {
            throw CloudKitMapperDecodeError.missingAsset
        }

        let encrypted = try Data(contentsOf: url)
        let json = try encryption.decrypt(encrypted, keyVersion: keyVersion)
        let payload = try JSONDecoder().decode(CloudKitMapperPayloads.CollectionPayload.self, from: json)

        return CollectionRecord(
            id: localId,
            name: payload.name,
            color: payload.color,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            deviceId: deviceId,
            isDeleted: isDeleted,
            ckSystemFields: nil
        )
    }

    static func decodeSmartList(
        from record: CKRecord,
        encryption: SyncEncryptionServiceProtocol
    ) throws -> SmartListRecord {
        guard let localId = record[Field.localId] as? String else {
            throw CloudKitMapperDecodeError.missingField(Field.localId)
        }

        let createdAt = record[Field.createdAt] as? Date ?? Date()
        let modifiedAt = record[Field.modifiedAt] as? Date ?? createdAt
        let deviceId = record[Field.deviceId] as? String ?? ""
        let isDeleted = record[Field.isDeleted] as? Bool ?? false
        let keyVersion = record[Field.payloadKeyVersion] as? Int ?? 1

        guard let asset = record[Field.payloadAsset] as? CKAsset,
              let url = asset.fileURL else {
            throw CloudKitMapperDecodeError.missingAsset
        }

        let encrypted = try Data(contentsOf: url)
        let json = try encryption.decrypt(encrypted, keyVersion: keyVersion)
        let payload = try JSONDecoder().decode(CloudKitMapperPayloads.SmartListPayload.self, from: json)

        return SmartListRecord(
            id: localId,
            name: payload.name,
            icon: payload.icon,
            color: payload.color,
            rules: payload.rules,
            matchMode: payload.matchMode,
            sortOrder: payload.sortOrder,
            isBuiltIn: payload.isBuiltIn,
            position: payload.position,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            deviceId: deviceId,
            isDeleted: isDeleted,
            ckSystemFields: nil
        )
    }
}
