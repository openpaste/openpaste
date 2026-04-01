import Foundation
import Testing
@testable import OpenPaste

struct URLMetadataServiceTests {

    // MARK: - Cache Behavior

    @Test func sensitiveURLReturnsNil() async {
        let service = URLMetadataService()
        let url = URL(string: "https://example.com")!
        let result = await service.fetch(url: url, isSensitive: true)
        #expect(result == nil)
    }

    @Test func clearCacheDoesNotCrash() async {
        let service = URLMetadataService()
        await service.clearCache()
        // Should not crash even with empty cache
    }

    @Test func sensitiveURLAlwaysSkipped() async {
        let service = URLMetadataService()
        let url = URL(string: "https://bank.example.com/account")!

        // Multiple calls with isSensitive should all return nil
        let r1 = await service.fetch(url: url, isSensitive: true)
        let r2 = await service.fetch(url: url, isSensitive: true)
        #expect(r1 == nil)
        #expect(r2 == nil)
    }

    // MARK: - CachedMetadata

    @Test func cachedMetadataNotExpiredWhenFresh() {
        let metadata = URLMetadataService.CachedMetadata(
            title: "Test Page",
            favicon: nil,
            fetchedAt: Date()
        )
        #expect(metadata.isExpired == false)
        #expect(metadata.title == "Test Page")
    }

    @Test func cachedMetadataExpiredAfterOneHour() {
        let metadata = URLMetadataService.CachedMetadata(
            title: "Old Page",
            favicon: nil,
            fetchedAt: Date().addingTimeInterval(-3601) // 1 hour + 1 second ago
        )
        #expect(metadata.isExpired == true)
    }

    @Test func cachedMetadataNotExpiredJustBeforeOneHour() {
        let metadata = URLMetadataService.CachedMetadata(
            title: "Recent Page",
            favicon: nil,
            fetchedAt: Date().addingTimeInterval(-3599) // just under 1 hour
        )
        #expect(metadata.isExpired == false)
    }

    @Test func cachedMetadataWithFavicon() {
        let faviconData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        let metadata = URLMetadataService.CachedMetadata(
            title: "Page with Icon",
            favicon: faviconData,
            fetchedAt: Date()
        )
        #expect(metadata.favicon != nil)
        #expect(metadata.favicon?.count == 4)
    }

    @Test func cachedMetadataNilTitle() {
        let metadata = URLMetadataService.CachedMetadata(
            title: nil,
            favicon: nil,
            fetchedAt: Date()
        )
        #expect(metadata.title == nil)
        #expect(metadata.favicon == nil)
    }
}
