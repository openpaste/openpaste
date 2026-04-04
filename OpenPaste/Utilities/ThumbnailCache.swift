import AppKit

/// Simple in-memory thumbnail cache using NSCache.
/// Avoids decoding full-resolution images inside SwiftUI body.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSUUID, NSImage>()
    private let sizeCache = NSCache<NSUUID, NSValue>()
    private let maxThumbnailSize: CGFloat = 320 // 2x card width for Retina

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        sizeCache.countLimit = 200
    }

    func thumbnail(for id: UUID, data: Data) -> NSImage? {
        let key = id as NSUUID

        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let original = NSImage(data: data) else { return nil }
        sizeCache.setObject(NSValue(size: original.size), forKey: key)

        let thumbnail = downsample(original)
        let cost = data.count
        cache.setObject(thumbnail, forKey: key, cost: cost)
        return thumbnail
    }

    func originalSize(for id: UUID, data: Data) -> NSSize? {
        let key = id as NSUUID

        if let cached = sizeCache.object(forKey: key) {
            return cached.sizeValue
        }

        guard let original = NSImage(data: data) else { return nil }
        sizeCache.setObject(NSValue(size: original.size), forKey: key)
        return original.size
    }

    func evict(for id: UUID) {
        let key = id as NSUUID
        cache.removeObject(forKey: key)
        sizeCache.removeObject(forKey: key)
    }

    private func downsample(_ image: NSImage) -> NSImage {
        let originalSize = image.size
        guard originalSize.width > maxThumbnailSize || originalSize.height > maxThumbnailSize else {
            return image
        }

        let scale = min(maxThumbnailSize / originalSize.width, maxThumbnailSize / originalSize.height)
        let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()
        return thumbnail
    }
}
