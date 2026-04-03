import Foundation

struct Collection: Identifiable, Sendable, Hashable {
    var id: UUID
    var name: String
    var color: String
    var createdAt: Date
    var modifiedAt: Date
    var deviceId: String
    var isDeleted: Bool

    init(
        id: UUID = UUID(),
        name: String,
        color: String = "#007AFF",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        deviceId: String = "",
        isDeleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.deviceId = deviceId
        self.isDeleted = isDeleted
    }
}
