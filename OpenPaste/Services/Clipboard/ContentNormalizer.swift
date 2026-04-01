import Foundation
import AppKit
import UniformTypeIdentifiers

final class ContentNormalizer: Sendable {
    private let hasher = ContentHasher()
    private let maxItemSize: Int

    init(maxItemSize: Int = 10_485_760) {
        self.maxItemSize = maxItemSize
    }

    nonisolated func normalize(from pasteboard: NSPasteboard) -> ClipboardItem? {
        guard let types = pasteboard.types, !types.isEmpty else { return nil }

        let sourceApp = getSourceApp()

        if let imageItem = extractImage(from: pasteboard, sourceApp: sourceApp) {
            return imageItem
        }
        if let fileItem = extractFiles(from: pasteboard, sourceApp: sourceApp) {
            return fileItem
        }
        if let urlItem = extractURL(from: pasteboard, sourceApp: sourceApp) {
            return urlItem
        }
        if let richTextItem = extractRichText(from: pasteboard, sourceApp: sourceApp) {
            return richTextItem
        }
        if let textItem = extractPlainText(from: pasteboard, sourceApp: sourceApp) {
            return textItem
        }
        if let colorItem = extractColor(from: pasteboard, sourceApp: sourceApp) {
            return colorItem
        }

        return nil
    }

    private nonisolated func extractPlainText(from pasteboard: NSPasteboard, sourceApp: AppInfo) -> ClipboardItem? {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return nil }
        let data = Data(text.utf8)
        guard data.count <= maxItemSize else { return nil }

        return ClipboardItem(
            type: looksLikeCode(text) ? .code : .text,
            content: data,
            plainTextContent: text,
            sourceApp: sourceApp,
            contentHash: hasher.hash(data)
        )
    }

    private nonisolated func extractRichText(from pasteboard: NSPasteboard, sourceApp: AppInfo) -> ClipboardItem? {
        guard let rtfData = pasteboard.data(forType: .rtf) ?? pasteboard.data(forType: .html) else { return nil }
        guard rtfData.count <= maxItemSize else { return nil }

        let plainText = pasteboard.string(forType: .string)

        return ClipboardItem(
            type: .richText,
            content: rtfData,
            plainTextContent: plainText,
            sourceApp: sourceApp,
            contentHash: hasher.hash(rtfData)
        )
    }

    private nonisolated func extractImage(from pasteboard: NSPasteboard, sourceApp: AppInfo) -> ClipboardItem? {
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        for type in imageTypes {
            if let imageData = pasteboard.data(forType: type), imageData.count <= maxItemSize {
                return ClipboardItem(
                    type: .image,
                    content: imageData,
                    sourceApp: sourceApp,
                    contentHash: hasher.hash(imageData)
                )
            }
        }
        return nil
    }

    private nonisolated func extractFiles(from pasteboard: NSPasteboard, sourceApp: AppInfo) -> ClipboardItem? {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], let firstURL = urls.first else { return nil }

        let pathData = Data(firstURL.path.utf8)
        let plainText = urls.map(\.path).joined(separator: "\n")

        return ClipboardItem(
            type: .file,
            content: pathData,
            plainTextContent: plainText,
            sourceApp: sourceApp,
            contentHash: hasher.hash(pathData),
            metadata: ["fileCount": "\(urls.count)", "fileName": firstURL.lastPathComponent]
        )
    }

    private nonisolated func extractURL(from pasteboard: NSPasteboard, sourceApp: AppInfo) -> ClipboardItem? {
        guard let urlString = pasteboard.string(forType: .string),
              let url = URL(string: urlString),
              url.scheme == "http" || url.scheme == "https" else { return nil }

        let data = Data(urlString.utf8)
        return ClipboardItem(
            type: .link,
            content: data,
            plainTextContent: urlString,
            sourceApp: sourceApp,
            sourceURL: url,
            contentHash: hasher.hash(data)
        )
    }

    private nonisolated func extractColor(from pasteboard: NSPasteboard, sourceApp: AppInfo) -> ClipboardItem? {
        guard let colorData = pasteboard.data(forType: .color) else { return nil }
        guard let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) else { return nil }

        let hexString = color.hexString
        let data = Data(hexString.utf8)
        return ClipboardItem(
            type: .color,
            content: data,
            plainTextContent: hexString,
            sourceApp: sourceApp,
            contentHash: hasher.hash(data)
        )
    }

    private nonisolated func getSourceApp() -> AppInfo {
        guard let app = NSWorkspace.shared.frontmostApplication else { return .unknown }
        return AppInfo(
            bundleId: app.bundleIdentifier ?? "",
            name: app.localizedName ?? "Unknown",
            iconPath: app.bundleURL?.appendingPathComponent("Contents/Resources/AppIcon.icns").path
        )
    }

    private nonisolated func looksLikeCode(_ text: String) -> Bool {
        let codePatterns = [
            #"^\s*(func |class |struct |enum |import |let |var |if |for |while |switch |return )"#,
            #"[{}\[\]();]"#,
            #"(=>|->|::|\.\.|\.\.\.)"#,
        ]
        for pattern in codePatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
}

private extension NSColor {
    var hexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
