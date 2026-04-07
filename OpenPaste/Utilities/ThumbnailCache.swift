import AppKit

/// Simple in-memory thumbnail cache using NSCache.
/// Supports both sync (with data) and async (on-demand from DB) loading.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    enum PreviewVariant: String {
        case card
        case list
        case detail
    }

    private let cache = NSCache<NSString, NSImage>()
    private let sizeCache = NSCache<NSUUID, NSValue>()
    private let maxThumbnailSize: CGFloat = 320 // 2x card width for Retina
    private(set) var storageService: StorageServiceProtocol?

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        sizeCache.countLimit = 200
    }

    /// Call once from DependencyContainer after init.
    func configure(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }

    // MARK: - Async Loading (preferred — no Data blob needed)

    /// Loads thumbnail asynchronously, fetching content from DB on cache miss.
    func loadThumbnailAsync(for id: UUID, variant: PreviewVariant = .card) async -> NSImage? {
        let cacheKey = "\(id.uuidString)-\(variant.rawValue)" as NSString

        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        guard let storageService else { return nil }
        guard let data = try? await storageService.fetchContent(for: id) else { return nil }

        // Decode on background
        return await Task.detached(priority: .utility) { [weak self] in
            guard let self else { return nil as NSImage? }
            guard let original = NSImage(data: data) else { return nil }
            self.sizeCache.setObject(NSValue(size: original.size), forKey: id as NSUUID)
            let thumbnail = self.downsample(original)
            let cost = Int(thumbnail.size.width * thumbnail.size.height * 4)
            self.cache.setObject(thumbnail, forKey: cacheKey, cost: cost)
            return thumbnail
        }.value
    }

    // MARK: - Sync Loading (legacy — requires Data blob)

    func thumbnail(for id: UUID, data: Data) -> NSImage? {
        let cacheKey = "\(id.uuidString)-card" as NSString

        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        guard let original = NSImage(data: data) else { return nil }
        sizeCache.setObject(NSValue(size: original.size), forKey: id as NSUUID)

        let thumbnail = downsample(original)
        let cost = Int(thumbnail.size.width * thumbnail.size.height * 4)
        cache.setObject(thumbnail, forKey: cacheKey, cost: cost)
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

    func originalSize(for id: UUID) -> NSSize? {
        let key = id as NSUUID
        return sizeCache.object(forKey: key)?.sizeValue
    }

    func evict(for id: UUID) {
        let key = id as NSUUID
        cache.removeObject(forKey: "\(id.uuidString)-card" as NSString)
        cache.removeObject(forKey: "\(id.uuidString)-list" as NSString)
        cache.removeObject(forKey: "\(id.uuidString)-detail" as NSString)
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
