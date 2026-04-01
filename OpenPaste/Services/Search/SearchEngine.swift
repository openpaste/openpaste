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
            var request = ClipboardItemRecord.all()

            if !trimmed.isEmpty {
                let likePattern = "%\(trimmed)%"
                request = request.filter(
                    Column("plainTextContent").like(likePattern) ||
                    Column("ocrText").like(likePattern) ||
                    Column("tags").like(likePattern) ||
                    Column("sourceAppName").like(likePattern)
                )
            }

            if let contentType = filters.contentType {
                request = request.filter(Column("type") == contentType.rawValue)
            }
            if let bundleId = filters.sourceAppBundleId {
                request = request.filter(Column("sourceAppBundleId") == bundleId)
            }
            if let dateFrom = filters.dateFrom {
                request = request.filter(Column("createdAt") >= dateFrom)
            }
            if let dateTo = filters.dateTo {
                request = request.filter(Column("createdAt") <= dateTo)
            }
            if filters.pinnedOnly {
                request = request.filter(Column("pinned") == true)
            }
            if filters.starredOnly {
                request = request.filter(Column("starred") == true)
            }

            return try request
                .order(Column("pinned").desc, Column("createdAt").desc)
                .limit(100)
                .fetchAll(db)
                .map { $0.toClipboardItem() }
        }
    }
}
