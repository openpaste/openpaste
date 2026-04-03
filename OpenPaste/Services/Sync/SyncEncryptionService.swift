import Foundation
import CryptoKit
import Security

protocol SyncEncryptionServiceProtocol: Sendable {
    func ensureKeyExists(version: Int) throws
    func encrypt(_ data: Data, keyVersion: Int) throws -> Data
    func decrypt(_ combined: Data, keyVersion: Int) throws -> Data
}

enum SyncEncryptionError: Error {
    case invalidKey
    case keychainError(OSStatus)
}

struct SyncEncryptionService: SyncEncryptionServiceProtocol {
    private static let service = "dev.tuanle.OpenPaste.sync"

    func ensureKeyExists(version: Int) throws {
        if try fetchKeyData(version: version) != nil { return }
        let key = SymmetricKey(size: .bits256)
        try storeKeyData(keyData: key.withUnsafeBytes { Data($0) }, version: version)
    }

    func encrypt(_ data: Data, keyVersion: Int) throws -> Data {
        let key = try loadKey(version: keyVersion)
        let sealed = try AES.GCM.seal(data, using: key)
        return sealed.combined ?? Data()
    }

    func decrypt(_ combined: Data, keyVersion: Int) throws -> Data {
        let key = try loadKey(version: keyVersion)
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }

    private func loadKey(version: Int) throws -> SymmetricKey {
        guard let keyData = try fetchKeyData(version: version) else {
            throw SyncEncryptionError.invalidKey
        }
        return SymmetricKey(data: keyData)
    }

    private func fetchKeyData(version: Int) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: "key_v\(version)",
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        if status != errSecSuccess { throw SyncEncryptionError.keychainError(status) }
        return item as? Data
    }

    private func storeKeyData(keyData: Data, version: Int) throws {
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: "key_v\(version)",
            kSecAttrSynchronizable as String: true,
            kSecValueData as String: keyData,
        ]

        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.service,
                kSecAttrAccount as String: "key_v\(version)",
                kSecAttrSynchronizable as String: true,
            ]
            let attrs: [String: Any] = [kSecValueData as String: keyData]
            let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
            if updateStatus != errSecSuccess { throw SyncEncryptionError.keychainError(updateStatus) }
            return
        }

        if status != errSecSuccess {
            throw SyncEncryptionError.keychainError(status)
        }
    }
}
