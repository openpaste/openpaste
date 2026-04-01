import Foundation

protocol ClipboardServiceProtocol: Sendable {
    func startMonitoring() async
    func stopMonitoring() async
    func pasteItem(_ item: ClipboardItem) async
}
