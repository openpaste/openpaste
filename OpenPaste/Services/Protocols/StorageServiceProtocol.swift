import Foundation

protocol StorageServiceProtocol: Sendable {
    func save(_ item: ClipboardItem) async throws
    func fetch(limit: Int, offset: Int) async throws -> [ClipboardItem]
    func delete(_ id: UUID) async throws
    func fetchByHash(_ hash: String) async throws -> ClipboardItem?
    func updateAccessCount(_ id: UUID) async throws
    func deleteExpired() async throws
    func itemCount() async throws -> Int
    func update(_ item: ClipboardItem) async throws
}
