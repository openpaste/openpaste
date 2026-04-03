import Foundation
@preconcurrency import CloudKit

enum CloudKitSystemFields {
    enum SystemFieldsError: Error {
        case unableToDecodeRecord
    }

    static func encode(from record: CKRecord) throws -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    static func decodeRecord(from data: Data) throws -> CKRecord {
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = true
        defer { unarchiver.finishDecoding() }

        guard let record = CKRecord(coder: unarchiver) else {
            throw SystemFieldsError.unableToDecodeRecord
        }
        return record
    }
}
