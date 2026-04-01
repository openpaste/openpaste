import Foundation

enum ContentType: String, Codable, Sendable, CaseIterable {
    case text
    case richText
    case image
    case file
    case link
    case color
    case code
}
