import Foundation
import Testing

@testable import OpenPaste

struct SensitiveContentDetectorTests {
    let detector = SensitiveContentDetector()

    @Test func detectsCreditCard() {
        #expect(detector.detectSensitive("4111 1111 1111 1111"))
    }

    @Test func detectsCreditCardWithDashes() {
        #expect(detector.detectSensitive("4111-1111-1111-1111"))
    }

    @Test func detectsAWSKey() {
        #expect(detector.detectSensitive("AKIAIOSFODNN7EXAMPLE"))
    }

    @Test func detectsGCPKey() {
        #expect(detector.detectSensitive("AIzaSyA-some-key-here-with-35-chars!!!"))
    }

    @Test func detectsStripeKey() {
        let prefix = "sk_" + "live_"
        let suffix = String(repeating: "a", count: 24)
        #expect(detector.detectSensitive(prefix + suffix))
    }

    @Test func detectsJWT() {
        #expect(
            detector.detectSensitive(
                "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc123def456"))
    }

    @Test func detectsPrivateKey() {
        #expect(detector.detectSensitive("-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQ"))
    }

    @Test func detectsSSN() {
        #expect(detector.detectSensitive("123-45-6789"))
    }

    @Test func detectsGenericAPIKey() {
        #expect(detector.detectSensitive("api_key=abcdef1234567890ABCDEF"))
    }

    @Test func doesNotFlagNormalText() {
        #expect(!detector.detectSensitive("Hello, this is a normal sentence about programming."))
    }

    @Test func doesNotFlagShortText() {
        #expect(!detector.detectSensitive("short"))
    }

    @Test func doesNotFlagNormalURL() {
        #expect(!detector.detectSensitive("https://example.com/page?id=123"))
    }

    @Test func detectsHighEntropyString() {
        // 21 unique chars in 21 length → entropy ≈ 4.39 > 4.0
        #expect(detector.detectSensitive("aB3$kL9mN2pQ5rT8xY7zW"))
    }

    @Test func ignoresEntropyForTextWithSpaces() {
        #expect(!detector.detectSensitive("this is a normal text with spaces and words"))
    }

    @Test func blacklistReadsFromUserDefaults() {
        // Seed UserDefaults with blacklisted apps
        let apps = [
            AppInfo(bundleId: "com.apple.keychainaccess", name: "Keychain Access", iconPath: nil),
            AppInfo(bundleId: "com.agilebits.onepassword7", name: "1Password 7", iconPath: nil),
            AppInfo(bundleId: "com.1password.1password", name: "1Password", iconPath: nil),
        ]
        let data = try! JSONEncoder().encode(apps)
        UserDefaults.standard.set(data, forKey: "blacklistedApps")
        defer { UserDefaults.standard.removeObject(forKey: "blacklistedApps") }

        #expect(detector.isBlacklisted(bundleId: "com.apple.keychainaccess"))
        #expect(detector.isBlacklisted(bundleId: "com.agilebits.onepassword7"))
        #expect(detector.isBlacklisted(bundleId: "com.1password.1password"))
    }

    @Test func doesNotBlacklistNormalApps() {
        UserDefaults.standard.removeObject(forKey: "blacklistedApps")
        #expect(!detector.isBlacklisted(bundleId: "com.apple.Safari"))
        #expect(!detector.isBlacklisted(bundleId: "com.apple.Terminal"))
    }

    @Test func removedAppIsNoLongerBlacklisted() {
        // Only Keychain in the list — 1Password removed
        let apps = [
            AppInfo(bundleId: "com.apple.keychainaccess", name: "Keychain Access", iconPath: nil)
        ]
        let data = try! JSONEncoder().encode(apps)
        UserDefaults.standard.set(data, forKey: "blacklistedApps")
        defer { UserDefaults.standard.removeObject(forKey: "blacklistedApps") }

        #expect(detector.isBlacklisted(bundleId: "com.apple.keychainaccess"))
        #expect(!detector.isBlacklisted(bundleId: "com.agilebits.onepassword7"))
    }

    @Test func suggestsExpiryForSensitiveItems() {
        let item = TestHelpers.makeTextItem(text: "AKIAIOSFODNN7EXAMPLE", isSensitive: true)
        let expiry = detector.suggestedExpiry(for: item)
        #expect(expiry != nil)
        if let expiry {
            #expect(expiry > Date())
        }
    }

    @Test func noExpiryForNonSensitiveItems() {
        let item = TestHelpers.makeTextItem()
        let expiry = detector.suggestedExpiry(for: item)
        #expect(expiry == nil)
    }
}
