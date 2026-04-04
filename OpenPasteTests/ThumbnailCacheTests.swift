import AppKit
import Testing
@testable import OpenPaste

struct ThumbnailCacheTests {

    @Test func originalSizeReturnsStoredDimensions() {
        let cache = ThumbnailCache.shared
        let id = UUID()
        let data = makePNGData(width: 80, height: 32)

        let size = cache.originalSize(for: id, data: data)

        #expect(size?.width == 80)
        #expect(size?.height == 32)
    }

    @Test func thumbnailGenerationCachesOriginalDimensions() {
        let cache = ThumbnailCache.shared
        let id = UUID()
        let data = makePNGData(width: 96, height: 40)

        _ = cache.thumbnail(for: id, data: data)
        let size = cache.originalSize(for: id, data: Data())

        #expect(size?.width == 96)
        #expect(size?.height == 40)
        cache.evict(for: id)
    }

    @Test func evictClearsCachedOriginalDimensions() {
        let cache = ThumbnailCache.shared
        let id = UUID()
        let data = makePNGData(width: 64, height: 24)

        _ = cache.originalSize(for: id, data: data)
        cache.evict(for: id)

        let sizeAfterEvict = cache.originalSize(for: id, data: Data())
        #expect(sizeAfterEvict == nil)
    }

    private func makePNGData(width: CGFloat, height: CGFloat) -> Data {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()

        let tiffData = try! #require(image.tiffRepresentation)
        let bitmap = try! #require(NSBitmapImageRep(data: tiffData))
        return try! #require(bitmap.representation(using: .png, properties: [:]))
    }
}
