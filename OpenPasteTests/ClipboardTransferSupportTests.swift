import AppKit
import Foundation
import Testing
import UniformTypeIdentifiers

@testable import OpenPaste

@MainActor
struct ClipboardTransferSupportTests {
    private actor SummaryProviderStorageService: StorageServiceProtocol {
        private let itemsByID: [UUID: ClipboardItem]

        init(itemsByID: [UUID: ClipboardItem]) {
            self.itemsByID = itemsByID
        }

        func save(_ item: ClipboardItem) async throws {}
        func fetch(limit: Int, offset: Int) async throws -> [ClipboardItem] { [] }
        func delete(_ id: UUID) async throws {}
        func deleteAll() async throws {}
        func fetchByHash(_ hash: String) async throws -> ClipboardItem? { nil }
        func updateAccessCount(_ id: UUID) async throws {}
        func deleteExpired() async throws {}
        func itemCount() async throws -> Int { itemsByID.count }
        func update(_ item: ClipboardItem) async throws {}
        func fetchSummaries(limit: Int, offset: Int) async throws -> [ClipboardItemSummary] { [] }
        func fetchSummaries(inCollection collectionId: UUID) async throws -> [ClipboardItemSummary]
        { [] }
        func fetchContent(for id: UUID) async throws -> Data? { itemsByID[id]?.content }
        func fetchFull(by id: UUID) async throws -> ClipboardItem? { itemsByID[id] }
        func fetchAllTags() async throws -> [String] { [] }
        func fetchCollections() async throws -> [Collection] { [] }
        func saveCollection(_ collection: Collection) async throws {}
        func deleteCollection(_ id: UUID) async throws {}
        func fetchItems(inCollection collectionId: UUID) async throws -> [ClipboardItem] { [] }
        func assignItemToCollection(itemId: UUID, collectionId: UUID?) async throws {}
    }

    private struct ProviderLoadTimeoutError: Error {}

    private final class ContinuationBox<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Value, Error>?

        init(_ continuation: CheckedContinuation<Value, Error>) {
            self.continuation = continuation
        }

        func resume(_ result: Result<Value, Error>) {
            lock.lock()
            guard let continuation else {
                lock.unlock()
                return
            }
            self.continuation = nil
            lock.unlock()

            switch result {
            case .success(let value):
                continuation.resume(returning: value)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }

    @Test func textItem_providerIncludesPlainTextAndReorderToken() async throws {
        let item = TestHelpers.makeTextItem(text: "Dragged text")
        let provider = ClipboardTransferSupport.makeDragItemProvider(for: item)

        #expect(provider.hasItemConformingToTypeIdentifier(UTType.openPasteReorderItem.identifier))

        let textData = try await loadData(from: provider, type: .utf8PlainText)
        #expect(String(decoding: textData, as: UTF8.self) == "Dragged text")
    }

    @Test func richTextHTML_isExportedAsRTFWithPlainTextFallback() async throws {
        let html = "<b>Hello Drag</b>"
        let item = ClipboardItem(
            type: .richText,
            content: Data(html.utf8),
            plainTextContent: "Hello Drag",
            contentHash: ContentHasher().hash(Data(html.utf8))
        )

        let provider = ClipboardTransferSupport.makeDragItemProvider(for: item)
        let rtfData = try await loadData(from: provider, type: .rtf)
        let textData = try await loadData(from: provider, type: .utf8PlainText)

        #expect(String(data: rtfData.prefix(5), encoding: .ascii) == "{\\rtf")
        #expect(String(decoding: textData, as: UTF8.self) == "Hello Drag")
    }

    @Test func imagePNG_isConvertedToTIFFForDragging() async throws {
        let pngData = try #require(makePNGData())
        let item = ClipboardItem(
            type: .image,
            content: pngData,
            contentHash: ContentHasher().hash(pngData)
        )

        let provider = ClipboardTransferSupport.makeDragItemProvider(for: item)
        let tiffData = try await loadData(from: provider, type: .tiff)

        #expect(NSImage(data: tiffData) != nil)
        #expect(tiffData != pngData)
    }

    @Test func fileItem_parsesMultipleFileURLs() {
        let paths = ["/tmp/alpha.txt", "/tmp/beta.txt"]
        let joined = paths.joined(separator: "\n")
        let item = ClipboardItem(
            type: .file,
            content: Data(paths[0].utf8),
            plainTextContent: joined,
            contentHash: ContentHasher().hash(Data(paths[0].utf8))
        )

        #expect(ClipboardTransferSupport.fileURLs(for: item).map(\.path) == paths)
    }

    @Test func summaryTextProvider_exportsFullTextInsteadOfTruncatedPreview() async throws {
        let text = String(repeating: "OpenPaste drag payload ", count: 40)
        let item = ClipboardItem(
            type: .text,
            content: Data(text.utf8),
            plainTextContent: text,
            contentHash: ContentHasher().hash(Data(text.utf8))
        )
        let summary = item.toSummary()
        #expect(summary.plainTextContent != text)
        #expect(summary.plainTextContent?.count == 501)

        let provider = ClipboardTransferSupport.makeDragItemProvider(
            for: summary,
            storageService: SummaryProviderStorageService(itemsByID: [item.id: item])
        )

        let textData = try await loadData(from: provider, type: .utf8PlainText)
        #expect(String(decoding: textData, as: UTF8.self) == text)
    }

    @Test func summaryRichTextHTML_isConvertedToRTFWithPlainTextFallback() async throws {
        let html = "<b>Hello Summary Drag</b>"
        let item = ClipboardItem(
            type: .richText,
            content: Data(html.utf8),
            plainTextContent: "Hello Summary Drag",
            contentHash: ContentHasher().hash(Data(html.utf8))
        )

        let provider = ClipboardTransferSupport.makeDragItemProvider(
            for: item.toSummary(),
            storageService: SummaryProviderStorageService(itemsByID: [item.id: item])
        )

        let rtfData = try await loadData(from: provider, type: .rtf)
        let textData = try await loadData(from: provider, type: .utf8PlainText)

        #expect(String(data: rtfData.prefix(5), encoding: .ascii) == "{\\rtf")
        #expect(String(decoding: textData, as: UTF8.self) == "Hello Summary Drag")
    }

    @Test func summaryLinkProvider_usesSourceURLWhenPlainTextIsNotURL() async throws {
        let title = "OpenPaste launch page"
        let url = try #require(URL(string: "https://example.com/openpaste"))
        let item = ClipboardItem(
            type: .link,
            content: Data(title.utf8),
            plainTextContent: title,
            sourceURL: url,
            contentHash: ContentHasher().hash(Data(title.utf8))
        )

        let provider = ClipboardTransferSupport.makeDragItemProvider(
            for: item.toSummary(),
            storageService: SummaryProviderStorageService(itemsByID: [item.id: item])
        )

        let loadedURL = try await loadObject(from: provider, ofClass: NSURL.self)
        let textData = try await loadData(from: provider, type: .utf8PlainText)

        #expect((loadedURL as URL).absoluteString == url.absoluteString)
        #expect(String(decoding: textData, as: UTF8.self) == title)
    }

    private func loadData(from provider: NSItemProvider, type: UTType) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let box = ContinuationBox(continuation)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                box.resume(.failure(ProviderLoadTimeoutError()))
            }

            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                if let error {
                    box.resume(.failure(error))
                    return
                }

                guard let data else {
                    box.resume(.failure(CocoaError(.fileReadUnknown)))
                    return
                }

                box.resume(.success(data))
            }
        }
    }

    private func loadObject<T: NSItemProviderReading>(
        from provider: NSItemProvider, ofClass: T.Type
    )
        async throws -> T
    {
        try await withCheckedThrowingContinuation { continuation in
            let box = ContinuationBox(continuation)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                box.resume(.failure(ProviderLoadTimeoutError()))
            }

            provider.loadObject(ofClass: ofClass) { object, error in
                if let error {
                    box.resume(.failure(error))
                    return
                }

                guard let object = object as? T else {
                    box.resume(.failure(CocoaError(.fileReadUnknown)))
                    return
                }

                box.resume(.success(object))
            }
        }
    }

    private func makePNGData() -> Data? {
        let size = NSSize(width: 8, height: 8)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemPink.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }

        return rep.representation(using: .png, properties: [:])
    }
}
