import Foundation
import Testing
@testable import OpenPaste

struct ContentHasherTests {
    let hasher = ContentHasher()

    @Test func hashesConsistently() {
        let data = Data("hello world".utf8)
        let hash1 = hasher.hash(data)
        let hash2 = hasher.hash(data)
        #expect(hash1 == hash2)
    }

    @Test func differentDataProducesDifferentHashes() {
        let hash1 = hasher.hash(Data("hello".utf8))
        let hash2 = hasher.hash(Data("world".utf8))
        #expect(hash1 != hash2)
    }

    @Test func hashIsSHA256Length() {
        let hash = hasher.hash(Data("test".utf8))
        #expect(hash.count == 64)
    }

    @Test func emptyDataProducesValidHash() {
        let hash = hasher.hash(Data())
        #expect(!hash.isEmpty)
        #expect(hash.count == 64)
    }

    @Test func hashIsHexString() {
        let hash = hasher.hash(Data("test".utf8))
        let validHex = CharacterSet(charactersIn: "0123456789abcdef")
        #expect(hash.unicodeScalars.allSatisfy { validHex.contains($0) })
    }
}
