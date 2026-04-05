import Foundation
import Testing
@testable import OpenPaste

@Suite(.serialized)
struct KeychainHelperTests {
    // NOTE: KeychainHelper methods are private (storePassphrase, retrievePassphrase, generateRandomPassphrase).
    // Only getOrCreatePassphrase() and deletePassphrase() are public/internal.
    // Tests exercise the public API: getOrCreatePassphrase round-trip, deletePassphrase, idempotency.
    // Keychain tests require a signed app + keychain entitlement; they may fail in CI
    // but should pass when run from Xcode locally.
    // Tests are serialized because they share the same Keychain entry.
    // IMPORTANT: Use a test-specific Keychain entry so we never rotate the app's real database passphrase.

    let helper = KeychainHelper(
        service: "\(Constants.bundleIdentifier).tests",
        passphraseKey: "database-encryption-key-tests"
    )

    // MARK: - Helpers

    private func cleanupKeychain() {
        try? helper.deletePassphrase()
    }

    // MARK: - Tests

    @Test func getOrCreatePassphraseReturnsNonEmpty() throws {
        cleanupKeychain()
        defer { cleanupKeychain() }

        let passphrase = try helper.getOrCreatePassphrase()
        #expect(!passphrase.isEmpty)
    }

    @Test func getOrCreatePassphraseIsBase64() throws {
        cleanupKeychain()
        defer { cleanupKeychain() }

        let passphrase = try helper.getOrCreatePassphrase()
        // A valid base64 string should decode to 32 bytes
        let decoded = Data(base64Encoded: passphrase)
        #expect(decoded != nil)
        #expect(decoded?.count == 32)
    }

    @Test func getOrCreatePassphraseReturnsSameOnSecondCall() throws {
        cleanupKeychain()
        defer { cleanupKeychain() }

        let first = try helper.getOrCreatePassphrase()
        let second = try helper.getOrCreatePassphrase()
        #expect(first == second)
    }

    @Test func deletePassphraseRemovesStored() throws {
        cleanupKeychain()
        defer { cleanupKeychain() }

        // Store one first
        let _ = try helper.getOrCreatePassphrase()

        // Delete
        try helper.deletePassphrase()

        // Next call should generate a new one (which proves old one was deleted)
        let newPassphrase = try helper.getOrCreatePassphrase()
        #expect(!newPassphrase.isEmpty)
    }

    @Test func deletePassphraseIdempotent() throws {
        cleanupKeychain()

        // Deleting when nothing is stored should not throw
        // (deletePassphrase allows errSecItemNotFound)
        try helper.deletePassphrase()
        try helper.deletePassphrase()
    }

    @Test func freshPassphraseIsDifferentAfterDelete() throws {
        cleanupKeychain()
        defer { cleanupKeychain() }

        let first = try helper.getOrCreatePassphrase()
        try helper.deletePassphrase()
        let second = try helper.getOrCreatePassphrase()

        // Random passphrases should be different (probabilistically)
        // This could theoretically fail with probability 1/2^256
        #expect(first != second)
    }

    @Test func keychainErrorDescriptions() {
        let storeErr = KeychainHelper.KeychainError.unableToStore(-25299)
        #expect(storeErr.errorDescription?.contains("Keychain store failed") == true)

        let retrieveErr = KeychainHelper.KeychainError.unableToRetrieve(-25300)
        #expect(retrieveErr.errorDescription?.contains("Keychain retrieve failed") == true)

        let deleteErr = KeychainHelper.KeychainError.unableToDelete(-25301)
        #expect(deleteErr.errorDescription?.contains("Keychain delete failed") == true)
    }
}
