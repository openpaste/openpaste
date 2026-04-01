import Foundation

protocol SearchServiceProtocol: Sendable {
    func search(query: String, filters: SearchFilters) async throws -> [ClipboardItem]
}
