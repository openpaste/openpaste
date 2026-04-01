import Foundation

final class SensitiveContentDetector: SecurityServiceProtocol, @unchecked Sendable {
    private var blacklistedBundleIds: Set<String>
    private let defaultBlacklist: Set<String> = [
        "com.apple.keychainaccess",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        "com.bitwarden.desktop",
        "com.lastpass.LastPass",
        "com.apple.Passwords",
    ]

    private let sensitivePatterns: [(String, String)] = [
        ("Credit Card", #"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b"#),
        ("AWS Key", #"AKIA[0-9A-Z]{16}"#),
        ("GCP Key", #"AIza[0-9A-Za-z\-_]{35}"#),
        ("Stripe Key", #"sk_(live|test)_[0-9a-zA-Z]{24,}"#),
        ("JWT Token", #"eyJ[A-Za-z0-9-_]+\.eyJ[A-Za-z0-9-_]+\.[A-Za-z0-9-_.+/=]+"#),
        ("Private Key", #"-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----"#),
        ("Generic API Key", #"(?i)(api[_-]?key|apikey|secret[_-]?key)\s*[:=]\s*['"]?[A-Za-z0-9/+=]{16,}"#),
        ("SSN", #"\b\d{3}-\d{2}-\d{4}\b"#),
    ]

    private var compiledPatterns: [(String, NSRegularExpression)] = []
    private let defaultExpiryInterval: TimeInterval

    init(
        additionalBlacklist: Set<String> = [],
        defaultExpiryInterval: TimeInterval = 3600
    ) {
        self.blacklistedBundleIds = defaultBlacklist.union(additionalBlacklist)
        self.defaultExpiryInterval = defaultExpiryInterval
        self.compiledPatterns = sensitivePatterns.compactMap { name, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            return (name, regex)
        }
    }

    nonisolated func detectSensitive(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for (_, regex) in compiledPatterns {
            if regex.firstMatch(in: text, options: [], range: range) != nil {
                return true
            }
        }
        return hasHighEntropy(text)
    }

    nonisolated func suggestedExpiry(for item: ClipboardItem) -> Date? {
        guard item.isSensitive else { return nil }
        return Date().addingTimeInterval(defaultExpiryInterval)
    }

    nonisolated func isBlacklisted(bundleId: String) -> Bool {
        blacklistedBundleIds.contains(bundleId)
    }

    func updateBlacklist(_ bundleIds: Set<String>) {
        blacklistedBundleIds = defaultBlacklist.union(bundleIds)
    }

    private nonisolated func hasHighEntropy(_ text: String) -> Bool {
        guard text.count >= 16 && text.count <= 256 else { return false }
        let hasSpaces = text.contains(" ")
        if hasSpaces { return false }

        var charCounts: [Character: Int] = [:]
        for char in text { charCounts[char, default: 0] += 1 }

        let length = Double(text.count)
        var entropy = 0.0
        for count in charCounts.values {
            let probability = Double(count) / length
            if probability > 0 {
                entropy -= probability * log2(probability)
            }
        }
        return entropy > 4.0
    }
}
