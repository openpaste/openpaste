import Foundation
import LinkPresentation
import AppKit

actor URLMetadataService {
    static let shared = URLMetadataService()
    
    private var cache: [URL: CachedMetadata] = [:]
    private var inFlightTasks: [URL: Task<CachedMetadata?, Never>] = [:]
    
    struct CachedMetadata: Sendable {
        let title: String?
        let favicon: Data?
        let fetchedAt: Date
        
        var isExpired: Bool {
            Date().timeIntervalSince(fetchedAt) > 3600 // 1-hour cache
        }
    }
    
    func fetch(url: URL, isSensitive: Bool = false) async -> CachedMetadata? {
        // Privacy gate: don't fetch for sensitive URLs
        guard !isSensitive else { return nil }
        
        // Return cached if valid
        if let cached = cache[url], !cached.isExpired {
            return cached
        }
        
        // Deduplicate in-flight requests
        if let existing = inFlightTasks[url] {
            return await existing.value
        }
        
        let task = Task<CachedMetadata?, Never> {
            await fetchMetadata(for: url)
        }
        inFlightTasks[url] = task
        let result = await task.value
        inFlightTasks.removeValue(forKey: url)
        return result
    }
    
    private func fetchMetadata(for url: URL) async -> CachedMetadata? {
        let provider = LPMetadataProvider()
        provider.timeout = 5
        provider.shouldFetchSubresources = true
        
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            var faviconData: Data?
            
            if let iconProvider = metadata.iconProvider {
                faviconData = try? await withCheckedThrowingContinuation { continuation in
                    iconProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                        if let data = data {
                            continuation.resume(returning: data)
                        } else {
                            continuation.resume(throwing: error ?? URLError(.unknown))
                        }
                    }
                }
            }
            
            let cached = CachedMetadata(
                title: metadata.title,
                favicon: faviconData,
                fetchedAt: Date()
            )
            cache[url] = cached
            return cached
        } catch {
            return nil
        }
    }
    
    func clearCache() {
        cache.removeAll()
    }
}
