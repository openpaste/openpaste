import Foundation
import GRDB

final class SearchEngine: SearchServiceProtocol, @unchecked Sendable {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func search(query: String, filters: SearchFilters) async throws -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return try await dbQueue.read { [filters] db in
            if trimmed.isEmpty {
                return try Self.searchFiltersOnly(db, filters: filters)
            }

            let ftsQuery = Self.buildFTS5Query(trimmed)
            guard !ftsQuery.isEmpty else {
                return try Self.searchFiltersOnly(db, filters: filters)
            }

            do {
                return try Self.searchWithFTS5(db, ftsQuery: ftsQuery, filters: filters)
            } catch {
                return try Self.searchWithLike(db, query: trimmed, filters: filters)
            }
        }
    }

    // MARK: - FTS5 Search

    private static func searchWithFTS5(_ db: Database, ftsQuery: String, filters: SearchFilters) throws -> [ClipboardItem] {
        var request = ClipboardItemRecord
            .filter(sql: """
                clipboardItems.rowid IN (
                    SELECT rowid FROM clipboardItemsFts WHERE clipboardItemsFts MATCH ?
                )
                """, arguments: [ftsQuery])

        request = applyFilters(request, filters: filters)

        return try request
            .order(Column("pinned").desc, Column("createdAt").desc)
            .limit(100)
            .fetchAll(db)
            .map { $0.toClipboardItem() }
    }

    // MARK: - LIKE Fallback

    private static func searchWithLike(_ db: Database, query: String, filters: SearchFilters) throws -> [ClipboardItem] {
        let likePattern = "%\(query)%"
        var request = ClipboardItemRecord.filter(
            Column("plainTextContent").like(likePattern) ||
            Column("ocrText").like(likePattern) ||
            Column("tags").like(likePattern) ||
            Column("sourceAppName").like(likePattern)
        )

        request = applyFilters(request, filters: filters)

        return try request
            .order(Column("pinned").desc, Column("createdAt").desc)
            .limit(100)
            .fetchAll(db)
            .map { $0.toClipboardItem() }
    }

    // MARK: - Filters Only

    private static func searchFiltersOnly(_ db: Database, filters: SearchFilters) throws -> [ClipboardItem] {
        guard filters != .empty else { return [] }
        var request = ClipboardItemRecord.all()
        request = applyFilters(request, filters: filters)

        return try request
            .order(Column("pinned").desc, Column("createdAt").desc)
            .limit(100)
            .fetchAll(db)
            .map { $0.toClipboardItem() }
    }

    // MARK: - Filter Application

    private static func applyFilters(_ request: QueryInterfaceRequest<ClipboardItemRecord>, filters: SearchFilters) -> QueryInterfaceRequest<ClipboardItemRecord> {
        var result = request
        if let contentType = filters.contentType {
            result = result.filter(Column("type") == contentType.rawValue)
        }
        if let bundleId = filters.sourceAppBundleId {
            result = result.filter(Column("sourceAppBundleId") == bundleId)
        }
        if let dateFrom = filters.dateFrom {
            result = result.filter(Column("createdAt") >= dateFrom)
        }
        if let dateTo = filters.dateTo {
            result = result.filter(Column("createdAt") <= dateTo)
        }
        if filters.pinnedOnly {
            result = result.filter(Column("pinned") == true)
        }
        if filters.starredOnly {
            result = result.filter(Column("starred") == true)
        }
        return result
    }

    // MARK: - FTS5 Query Builder

    static func buildFTS5Query(_ input: String) -> String {
        let tokens = input.split(separator: " ").compactMap { token -> String? in
            var cleaned = String(token)
            for char in ["\"", "*", "(", ")", ":", "^", "+"] {
                cleaned = cleaned.replacingOccurrences(of: char, with: "")
            }
            let reserved = ["AND", "OR", "NOT", "NEAR"]
            if reserved.contains(cleaned.uppercased()) {
                return "\"\(cleaned)\"*"
            }
            guard !cleaned.isEmpty else { return nil }
            return "\"\(cleaned)\"*"
        }
        return tokens.joined(separator: " ")
    }
}
