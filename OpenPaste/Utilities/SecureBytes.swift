import Foundation

/// Secure wrapper for sensitive byte data. Zeroes memory on deallocation using `memset_s`.
final class SecureBytes: @unchecked Sendable {
    private var bytes: [UInt8]
    
    init(_ data: Data) {
        self.bytes = Array(data)
    }
    
    init(count: Int) {
        self.bytes = [UInt8](repeating: 0, count: count)
    }
    
    var data: Data { Data(bytes) }
    var count: Int { bytes.count }
    var isEmpty: Bool { bytes.isEmpty }
    
    deinit {
        zeroOut()
    }
    
    /// Explicitly zero out the contents (also called automatically in deinit)
    func zeroOut() {
        guard !bytes.isEmpty else { return }
        bytes.withUnsafeMutableBufferPointer { buffer in
            guard let ptr = buffer.baseAddress else { return }
            // memset_s is guaranteed not to be optimized away by the compiler
            memset_s(ptr, buffer.count, 0, buffer.count)
        }
    }
    
    /// Perform a read operation on the secure data
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}

#if DEBUG
enum SecureBytesDebugHooks {
    private static let lock = NSLock()
    private static var hook: ((_ byteCount: Int) -> Void)?

    static var onDataSecureZero: ((_ byteCount: Int) -> Void)? {
        get {
            lock.lock(); defer { lock.unlock() }
            return hook
        }
        set {
            lock.lock()
            hook = newValue
            lock.unlock()
        }
    }

    static func notifyDataSecureZero(byteCount: Int) {
        lock.lock()
        let current = hook
        lock.unlock()
        current?(byteCount)
    }
}
#endif

extension Data {
    /// Zero out the contents of this Data object
    mutating func secureZero() {
        let count = self.count
        withUnsafeMutableBytes { buffer in
            guard let ptr = buffer.baseAddress else { return }
            memset_s(ptr, buffer.count, 0, buffer.count)
        }

        #if DEBUG
        SecureBytesDebugHooks.notifyDataSecureZero(byteCount: count)
        #endif

        self = Data()
    }
}
