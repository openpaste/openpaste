import Foundation

enum AppEvent: Sendable {
    case clipboardChanged(ClipboardItem)
    case itemStored(ClipboardItem)
    case itemPasted(ClipboardItem)
    case searchRequested(query: String)
    case stackPasted(items: [ClipboardItem])
    case previewOpened(ClipboardItem)
    case sensitiveDetected(ClipboardItem)
    case ocrCompleted(item: ClipboardItem, extractedText: String)
    case settingsUpdated(key: String, value: String)

    // Sync
    case syncStarted
    case syncCompleted
    case syncFailed(String)
}
