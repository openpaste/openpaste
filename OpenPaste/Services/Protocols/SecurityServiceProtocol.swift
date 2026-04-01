import Foundation

protocol SecurityServiceProtocol: Sendable {
    func detectSensitive(_ text: String) -> Bool
    func suggestedExpiry(for item: ClipboardItem) -> Date?
    func isBlacklisted(bundleId: String) -> Bool
}
