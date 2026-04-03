import Foundation
@preconcurrency import CloudKit

enum CloudKitMapper {
    static let containerIdentifier = "iCloud.dev.tuanle.OpenPaste"
    static let zoneID = CKRecordZone.ID(zoneName: "OpenPasteZone", ownerName: CKCurrentUserDefaultName)

    enum RecordType {
        static let clipboardItem = "ClipboardItem"
        static let collection = "Collection"
    }

    enum Field {
        static let localId = "localId"
        static let createdAt = "createdAt"
        static let modifiedAt = "modifiedAt"
        static let deviceId = "deviceId"
        static let isDeleted = "isDeleted"
        static let syncVersion = "syncVersion"
        static let payloadKeyVersion = "payloadKeyVersion"
        static let payloadAsset = "payloadAsset"
        static let contentHash = "contentHash"
    }

    static func makeClipboardItemRecord(
        recordName: String,
        local: ClipboardItemRecord,
        keyVersion: Int,
        encryption: SyncEncryptionServiceProtocol
    ) throws -> (record: CKRecord, stagedFileURL: URL) {
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        let record: CKRecord
        if let system = local.ckSystemFields {
            record = try CloudKitSystemFields.decodeRecord(from: system)
        } else {
            record = CKRecord(recordType: RecordType.clipboardItem, recordID: recordID)
        }

        record[Field.localId] = local.id
        record[Field.createdAt] = local.createdAt
        record[Field.modifiedAt] = local.modifiedAt
        record[Field.deviceId] = local.deviceId
        record[Field.isDeleted] = local.isDeleted
        record[Field.syncVersion] = local.syncVersion
        record[Field.payloadKeyVersion] = keyVersion
        record[Field.contentHash] = local.contentHash

        let payload = CloudKitMapperPayloads.ClipboardItemPayload(
            type: local.type,
            content: local.content,
            plainTextContent: local.plainTextContent,
            ocrText: local.ocrText,
            sourceAppBundleId: local.sourceAppBundleId,
            sourceAppName: local.sourceAppName,
            sourceAppIconPath: local.sourceAppIconPath,
            sourceURL: local.sourceURL,
            tags: local.tags,
            pinned: local.pinned,
            starred: local.starred,
            collectionId: local.collectionId,
            contentHash: local.contentHash,
            isSensitive: local.isSensitive,
            expiresAt: local.expiresAt,
            metadata: local.metadata
        )

        let (asset, url) = try stageEncryptedPayload(payload, keyVersion: keyVersion, encryption: encryption)
        record[Field.payloadAsset] = asset
        return (record, url)
    }

    static func makeCollectionRecord(
        recordName: String,
        local: CollectionRecord,
        keyVersion: Int,
        encryption: SyncEncryptionServiceProtocol
    ) throws -> (record: CKRecord, stagedFileURL: URL) {
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        let record: CKRecord
        if let system = local.ckSystemFields {
            record = try CloudKitSystemFields.decodeRecord(from: system)
        } else {
            record = CKRecord(recordType: RecordType.collection, recordID: recordID)
        }

        record[Field.localId] = local.id
        record[Field.createdAt] = local.createdAt
        record[Field.modifiedAt] = local.modifiedAt
        record[Field.deviceId] = local.deviceId
        record[Field.isDeleted] = local.isDeleted
        record[Field.payloadKeyVersion] = keyVersion

        let payload = CloudKitMapperPayloads.CollectionPayload(name: local.name, color: local.color)
        let (asset, url) = try stageEncryptedPayload(payload, keyVersion: keyVersion, encryption: encryption)
        record[Field.payloadAsset] = asset
        return (record, url)
    }

    private static func stageEncryptedPayload<T: Encodable>(
        _ payload: T,
        keyVersion: Int,
        encryption: SyncEncryptionServiceProtocol
    ) throws -> (asset: CKAsset, url: URL) {
        let json = try JSONEncoder().encode(payload)
        try encryption.ensureKeyExists(version: keyVersion)
        let encrypted = try encryption.encrypt(json, keyVersion: keyVersion)

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenPaste-Sync", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(UUID().uuidString).appendingPathExtension("bin")
        try encrypted.write(to: url, options: [.atomic])

        return (CKAsset(fileURL: url), url)
    }
}
