import Foundation

struct AppInfo: Codable, Sendable, Hashable {
    let bundleId: String
    let name: String
    let iconPath: String?

    static let unknown = AppInfo(bundleId: "", name: "Unknown", iconPath: nil)
}
