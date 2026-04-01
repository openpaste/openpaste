import Foundation

protocol OCRServiceProtocol: Sendable {
    func extractText(from imageData: Data) async throws -> String?
}
