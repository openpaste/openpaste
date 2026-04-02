import Foundation

enum TimeRange: String, CaseIterable, Identifiable, Sendable {
    case last24h = "Last 24h"
    case last7d = "Last 7 days"
    case last30d = "Last 30 days"

    var id: String { rawValue }

    var dateFrom: Date {
        switch self {
        case .last24h: Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        case .last7d: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .last30d: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        }
    }
}

struct SearchFilters: Sendable {
    var contentType: ContentType?
    var sourceAppBundleId: String?
    var dateFrom: Date?
    var dateTo: Date?
    var pinnedOnly: Bool = false
    var starredOnly: Bool = false
    var tags: [String] = []
    var collectionId: UUID?
    var timeRange: TimeRange?

    static let empty = SearchFilters()
}
