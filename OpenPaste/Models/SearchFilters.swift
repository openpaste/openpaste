import Foundation

struct SearchFilters: Sendable {
    var contentType: ContentType?
    var sourceAppBundleId: String?
    var dateFrom: Date?
    var dateTo: Date?
    var pinnedOnly: Bool = false
    var starredOnly: Bool = false
    var tags: [String] = []

    static let empty = SearchFilters()
}
