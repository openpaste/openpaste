import Foundation
import AppKit
import CryptoKit

final class ContentHasher: Sendable {
    nonisolated func hash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
