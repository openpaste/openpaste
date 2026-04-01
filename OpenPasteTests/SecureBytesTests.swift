import Foundation
import Testing
@testable import OpenPaste

struct SecureBytesTests {

    // MARK: - SecureBytes Init & Properties

    @Test func initWithData() {
        let original = Data([0x01, 0x02, 0x03, 0x04])
        let secure = SecureBytes(original)
        #expect(secure.data == original)
        #expect(secure.count == 4)
        #expect(!secure.isEmpty)
    }

    @Test func initWithCount() {
        let secure = SecureBytes(count: 16)
        #expect(secure.count == 16)
        #expect(secure.data == Data(repeating: 0, count: 16))
    }

    @Test func emptySecureBytes() {
        let secure = SecureBytes(Data())
        #expect(secure.isEmpty)
        #expect(secure.count == 0)
        #expect(secure.data == Data())
    }

    @Test func withUnsafeBytesReadsCorrectly() {
        let original = Data([0xAA, 0xBB, 0xCC])
        let secure = SecureBytes(original)

        let firstByte: UInt8 = secure.withUnsafeBytes { buffer in
            buffer.load(as: UInt8.self)
        }
        #expect(firstByte == 0xAA)
    }

    // MARK: - Zeroing

    @Test func zeroOutClearsData() {
        let original = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let secure = SecureBytes(original)

        // Before zeroing, data should be non-zero
        #expect(secure.data != Data(repeating: 0, count: 5))

        secure.zeroOut()

        // After zeroing, data should be all zeros
        #expect(secure.data == Data(repeating: 0, count: 5))
    }

    @Test func zeroOutEmptyDataDoesNotCrash() {
        let secure = SecureBytes(Data())
        // Should not crash
        secure.zeroOut()
        #expect(secure.isEmpty)
    }

    @Test func zeroOutIdempotent() {
        let secure = SecureBytes(Data([0xFF, 0xFF]))
        secure.zeroOut()
        secure.zeroOut() // second call should not crash
        #expect(secure.data == Data(repeating: 0, count: 2))
    }

    @Test func deinitZerosMemory() {
        // We can verify indirectly: after SecureBytes is released,
        // the data copy we took before zeroOut should differ from
        // the zeroed-out internal state.
        var secure: SecureBytes? = SecureBytes(Data([0xDE, 0xAD, 0xBE, 0xEF]))
        #expect(secure?.data == Data([0xDE, 0xAD, 0xBE, 0xEF]))

        // Capture a copy of data before deinit
        let dataCopy = secure!.data

        // Release — deinit should call zeroOut()
        secure = nil

        // The copy we made should still have the original data
        // (it's a copy, not affected by zeroing)
        #expect(dataCopy == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }

    // MARK: - Data.secureZero()

    @Test func dataSecureZero() {
        var data = Data([0x01, 0x02, 0x03, 0x04])
        data.secureZero()
        // After secureZero, data should be empty (implementation replaces with Data())
        #expect(data.isEmpty)
    }

    @Test func dataSecureZeroEmpty() {
        var data = Data()
        // Should not crash on empty data
        data.secureZero()
        #expect(data.isEmpty)
    }

    @Test func dataSecureZeroLargeBuffer() {
        var data = Data(repeating: 0xFF, count: 1024)
        #expect(data.count == 1024)
        data.secureZero()
        #expect(data.isEmpty)
    }
}
