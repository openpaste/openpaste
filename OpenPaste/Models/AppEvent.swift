import Foundation

enum AppEvent: Sendable {
    case clipboardChanged(ClipboardItem)
    case itemStored(ClipboardItem)
    case itemPasted(ClipboardItem)
    case searchRequested(query: String)
    case sensitiveDetected(ClipboardItem)
    case ocrCompleted(item: ClipboardItem, extractedText: String)
    case settingsUpdated(key: String, value: String)
}
