import AppKit
import Foundation
import UniformTypeIdentifiers

enum ClipboardTransferSupport {
    static func makeDragItemProvider(for item: ClipboardItem) -> NSItemProvider {
        let provider = baseProvider(for: item)
        registerReorderToken(for: item, on: provider)
        registerAdditionalRepresentations(for: item, on: provider)
        return provider
    }

    static func writeToPasteboard(_ item: ClipboardItem, pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        switch item.type {
        case .text, .code, .color:
            if let text = plainText(for: item) {
                pasteboard.setString(text, forType: .string)
            }
        case .richText:
            if let richTextData = richTextData(for: item) {
                pasteboard.setData(richTextData, forType: .rtf)
            }
            if let text = plainText(for: item) {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let tiffData = imageTIFFData(for: item) {
                pasteboard.setData(tiffData, forType: .tiff)
            }
        case .file:
            let urls = fileURLs(for: item)
            if !urls.isEmpty {
                pasteboard.writeObjects(urls as [NSURL])
            }
        case .link:
            if let url = linkURL(for: item) {
                pasteboard.writeObjects([url as NSURL])
            }
            if let text = plainText(for: item) {
                pasteboard.setString(text, forType: .string)
            }
        }
    }

    static func plainText(for item: ClipboardItem) -> String? {
        item.plainTextContent ?? String(data: item.content, encoding: .utf8)
    }

    static func richTextData(for item: ClipboardItem) -> Data? {
        guard item.type == .richText else { return nil }
        if isRTF(item.content) {
            return item.content
        }

        guard let attributedString = attributedString(for: item) else { return nil }
        let range = NSRange(location: 0, length: attributedString.length)
        return try? attributedString.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    static func imageTIFFData(for item: ClipboardItem) -> Data? {
        guard item.type == .image else { return nil }
        guard let image = NSImage(data: item.content) else {
            return item.content.isEmpty ? nil : item.content
        }
        return image.tiffRepresentation ?? item.content
    }

    static func fileURLs(for item: ClipboardItem) -> [URL] {
        guard item.type == .file, let text = plainText(for: item) else { return [] }
        return
            text
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
    }

    static func linkURL(for item: ClipboardItem) -> URL? {
        guard item.type == .link else { return nil }
        return item.sourceURL ?? plainText(for: item).flatMap(URL.init(string:))
    }

    private static func baseProvider(for item: ClipboardItem) -> NSItemProvider {
        switch item.type {
        case .text, .code, .color:
            if let text = plainText(for: item) {
                return NSItemProvider(object: text as NSString)
            }
        case .link:
            if let url = linkURL(for: item) {
                return NSItemProvider(object: url as NSURL)
            }
            if let text = plainText(for: item) {
                return NSItemProvider(object: text as NSString)
            }
        case .image:
            if let data = imageTIFFData(for: item), let image = NSImage(data: data) {
                return NSItemProvider(object: image)
            }
        case .file:
            if let firstURL = fileURLs(for: item).first {
                return NSItemProvider(object: firstURL as NSURL)
            }
            if let text = plainText(for: item) {
                return NSItemProvider(object: text as NSString)
            }
        case .richText:
            break
        }

        return NSItemProvider()
    }

    private static func registerReorderToken(for item: ClipboardItem, on provider: NSItemProvider) {
        let data = Data(item.id.uuidString.utf8)
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.openPasteReorderItem.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(data, nil)
            return nil
        }
    }

    private static func registerAdditionalRepresentations(
        for item: ClipboardItem,
        on provider: NSItemProvider
    ) {
        switch item.type {
        case .text, .code, .color:
            if let text = plainText(for: item) {
                registerPlainText(text, on: provider)
            }
        case .richText:
            if let data = richTextData(for: item) {
                provider.registerDataRepresentation(
                    forTypeIdentifier: UTType.rtf.identifier,
                    visibility: .all
                ) { completion in
                    completion(data, nil)
                    return nil
                }
            }
            if let text = plainText(for: item) {
                registerPlainText(text, on: provider)
            }
        case .link, .file:
            if let text = plainText(for: item) {
                registerPlainText(text, on: provider)
            }
        case .image:
            if let data = imageTIFFData(for: item) {
                provider.registerDataRepresentation(
                    forTypeIdentifier: UTType.tiff.identifier,
                    visibility: .all
                ) { completion in
                    completion(data, nil)
                    return nil
                }
            }
        }
    }

    private static func registerPlainText(_ text: String, on provider: NSItemProvider) {
        let data = Data(text.utf8)
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.utf8PlainText.identifier,
            visibility: .all
        ) { completion in
            completion(data, nil)
            return nil
        }
    }

    private static func attributedString(for item: ClipboardItem) -> NSAttributedString? {
        let documentTypes: [NSAttributedString.DocumentType] = [.rtf, .html]

        for documentType in documentTypes {
            if let attributedString = try? NSAttributedString(
                data: item.content,
                options: [.documentType: documentType],
                documentAttributes: nil
            ) {
                return attributedString
            }
        }

        if let text = plainText(for: item) {
            return NSAttributedString(string: text)
        }

        return nil
    }

    private static func isRTF(_ data: Data) -> Bool {
        let prefix = String(data: data.prefix(5), encoding: .ascii)
        return prefix == "{\\rtf"
    }
}
