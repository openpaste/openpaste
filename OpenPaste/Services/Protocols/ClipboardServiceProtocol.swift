import Foundation

protocol ClipboardServiceProtocol: Sendable {
    func startMonitoring() async
    func stopMonitoring() async
    func pasteItem(_ item: ClipboardItem) async
    /// Copy item content to the system clipboard without simulating paste.
    func copyToClipboard(_ item: ClipboardItem) async
    /// Simulate ⌘V to paste into the frontmost application.
    /// - Parameter targetBundleId: If provided, waits for this specific app to become active before pasting.
    func simulatePasteToFrontApp(targetBundleId: String?) async
}
