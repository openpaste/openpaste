import Foundation

struct Collection: Identifiable, Sendable, Hashable {
    var id: UUID
    var name: String
    var color: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, color: String = "#007AFF", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
    }
}
