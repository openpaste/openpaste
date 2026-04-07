import Foundation

protocol StorageServiceProtocol: Sendable {
    func save(_ item: ClipboardItem) async throws
    func fetch(limit: Int, offset: Int) async throws -> [ClipboardItem]
    func delete(_ id: UUID) async throws
    func deleteAll() async throws
    func fetchByHash(_ hash: String) async throws -> ClipboardItem?
    func updateAccessCount(_ id: UUID) async throws
    func deleteExpired() async throws
    func itemCount() async throws -> Int
    func update(_ item: ClipboardItem) async throws

    // Lightweight fetches — excludes content BLOB
    func fetchSummaries(limit: Int, offset: Int) async throws -> [ClipboardItemSummary]
    func fetchSummaries(inCollection collectionId: UUID) async throws -> [ClipboardItemSummary]

    // On-demand content loading
    func fetchContent(for id: UUID) async throws -> Data?
    func fetchFull(by id: UUID) async throws -> ClipboardItem?

    // Tags-only query (no full records)
    func fetchAllTags() async throws -> [String]

    // Collections
    func fetchCollections() async throws -> [Collection]
    func saveCollection(_ collection: Collection) async throws
    func deleteCollection(_ id: UUID) async throws
    func fetchItems(inCollection collectionId: UUID) async throws -> [ClipboardItem]
    func assignItemToCollection(itemId: UUID, collectionId: UUID?) async throws
}

