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

    nonisolated static func plainText(for item: ClipboardItem) -> String? {
        item.plainTextContent ?? String(data: item.content, encoding: .utf8)
    }

    nonisolated static func richTextData(for item: ClipboardItem) -> Data? {
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

    nonisolated static func imageTIFFData(for item: ClipboardItem) -> Data? {
        guard item.type == .image else { return nil }
        guard let image = NSImage(data: item.content) else {
            return item.content.isEmpty ? nil : item.content
        }
        return image.tiffRepresentation ?? item.content
    }

    nonisolated static func fileURLs(for item: ClipboardItem) -> [URL] {
        guard item.type == .file, let text = plainText(for: item) else { return [] }
        return
            text
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
    }

    nonisolated static func linkURL(for item: ClipboardItem) -> URL? {
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
        registerReorderToken(id: item.id, on: provider)
    }

    private static func registerReorderToken(id: UUID, on provider: NSItemProvider) {
        let data = Data(id.uuidString.utf8)
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

    private nonisolated static func attributedString(for item: ClipboardItem) -> NSAttributedString?
    {
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

    private nonisolated static func isRTF(_ data: Data) -> Bool {
        let prefix = String(data: data.prefix(5), encoding: .ascii)
        return prefix == "{\\rtf"
    }

    // MARK: - Summary-based Drag (async content loading)

    /// Creates a drag provider for a summary. Text/link/code/color items use
    /// plainTextContent directly. Image/richText/file items load content lazily
    /// via the storageService to avoid keeping blobs in RAM.
    static func makeDragItemProvider(
        for summary: ClipboardItemSummary,
        storageService: StorageServiceProtocol
    ) -> NSItemProvider {
        let provider = NSItemProvider()
        registerReorderToken(id: summary.id, on: provider)

        let loadCanonicalItem: @Sendable () async -> ClipboardItem? = {
            if let item = try? await storageService.fetchFull(by: summary.id) {
                return item
            }
            return fallbackItem(from: summary)
        }

        switch summary.type {
        case .text, .code, .color:
            registerAsyncObject(ofClass: NSString.self, on: provider) {
                await loadCanonicalItem().flatMap(plainText(for:)).map { $0 as NSString }
            }
            registerAsyncPlainText(on: provider) {
                await loadCanonicalItem().flatMap(plainText(for:))
            }
        case .link:
            registerAsyncObject(ofClass: NSURL.self, on: provider) {
                await loadCanonicalItem().flatMap(linkURL(for:)).map { $0 as NSURL }
            }
            registerAsyncPlainText(on: provider) {
                await loadCanonicalItem().flatMap(plainText(for:))
            }
        case .image:
            registerAsyncObject(ofClass: NSImage.self, on: provider) {
                await loadCanonicalItem()
                    .flatMap(imageTIFFData(for:))
                    .flatMap(NSImage.init(data:))
            }
            registerAsyncData(for: .tiff, on: provider) {
                await loadCanonicalItem().flatMap(imageTIFFData(for:))
            }
        case .richText:
            registerAsyncData(for: .rtf, on: provider) {
                await loadCanonicalItem().flatMap(richTextData(for:))
            }
            registerAsyncPlainText(on: provider) {
                await loadCanonicalItem().flatMap(plainText(for:))
            }
        case .file:
            registerAsyncObject(ofClass: NSURL.self, on: provider) {
                await loadCanonicalItem()
                    .flatMap { fileURLs(for: $0).first }
                    .map { $0 as NSURL }
            }
            registerAsyncPlainText(on: provider) {
                await loadCanonicalItem().flatMap(plainText(for:))
            }
        }

        return provider
    }

    private static func registerAsyncData(
        for type: UTType,
        on provider: NSItemProvider,
        load: @escaping @Sendable () async -> Data?
    ) {
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) {
            completion in
            Task {
                completion(await load(), nil)
            }
            return nil
        }
    }

    private static func registerAsyncObject<T: NSItemProviderWriting>(
        ofClass objectClass: T.Type,
        on provider: NSItemProvider,
        load: @escaping @Sendable () async -> T?
    ) {
        provider.registerObject(ofClass: objectClass, visibility: .all) { completion in
            Task {
                completion(await load(), nil)
            }
            return nil
        }
    }

    private static func registerAsyncPlainText(
        on provider: NSItemProvider,
        load: @escaping @Sendable () async -> String?
    ) {
        registerAsyncData(for: .utf8PlainText, on: provider) {
            await load().map { Data($0.utf8) }
        }
    }

    private nonisolated static func fallbackItem(from summary: ClipboardItemSummary)
        -> ClipboardItem?
    {
        switch summary.type {
        case .text, .code, .color, .file:
            guard let text = summary.plainTextContent else { return nil }
            return ClipboardItem(
                id: summary.id,
                type: summary.type,
                content: Data(text.utf8),
                plainTextContent: text,
                ocrText: summary.ocrText,
                sourceApp: summary.sourceApp,
                sourceURL: summary.sourceURL,
                createdAt: summary.createdAt,
                modifiedAt: summary.modifiedAt,
                tags: summary.tags,
                pinned: summary.pinned,
                starred: summary.starred,
                collectionId: summary.collectionId,
                contentHash: summary.contentHash,
                isSensitive: summary.isSensitive,
                metadata: summary.metadata
            )
        case .link:
            let linkText = summary.plainTextContent ?? summary.sourceURL?.absoluteString
            guard let linkText else { return nil }
            return ClipboardItem(
                id: summary.id,
                type: .link,
                content: Data(linkText.utf8),
                plainTextContent: linkText,
                ocrText: summary.ocrText,
                sourceApp: summary.sourceApp,
                sourceURL: summary.sourceURL,
                createdAt: summary.createdAt,
                modifiedAt: summary.modifiedAt,
                tags: summary.tags,
                pinned: summary.pinned,
                starred: summary.starred,
                collectionId: summary.collectionId,
                contentHash: summary.contentHash,
                isSensitive: summary.isSensitive,
                metadata: summary.metadata
            )
        case .richText, .image:
            return nil
        }
    }
}
