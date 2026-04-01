import Foundation
import Security

final class KeychainHelper: @unchecked Sendable {
    static let shared = KeychainHelper()
    
    private let service = Constants.bundleIdentifier
    private let passphraseKey = "database-encryption-key"
    
    func getOrCreatePassphrase() throws -> String {
        if let existing = try? retrievePassphrase() {
            return existing
        }
        let passphrase = generateRandomPassphrase()
        try storePassphrase(passphrase)
        return passphrase
    }
    
    private func generateRandomPassphrase() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            fatalError("[KeychainHelper] SecRandomCopyBytes failed with status \(status)")
        }
        return Data(bytes).base64EncodedString()
    }
    
    private func storePassphrase(_ passphrase: String) throws {
        let data = Data(passphrase.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passphraseKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore(status)
        }
    }
    
    private func retrievePassphrase() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passphraseKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let passphrase = String(data: data, encoding: .utf8) else {
            throw KeychainError.unableToRetrieve(status)
        }
        return passphrase
    }
    
    func deletePassphrase() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passphraseKey
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status)
        }
    }
    
    enum KeychainError: Error, LocalizedError {
        case unableToStore(OSStatus)
        case unableToRetrieve(OSStatus)
        case unableToDelete(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .unableToStore(let s): return "Keychain store failed: \(s)"
            case .unableToRetrieve(let s): return "Keychain retrieve failed: \(s)"
            case .unableToDelete(let s): return "Keychain delete failed: \(s)"
            }
        }
    }
}
