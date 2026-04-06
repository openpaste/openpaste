import AppKit
import Foundation
import Testing
import UniformTypeIdentifiers

@testable import OpenPaste

struct ClipboardTransferSupportTests {
    private struct ProviderLoadTimeoutError: Error {}

    private final class ContinuationBox: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Data, Error>?

        init(_ continuation: CheckedContinuation<Data, Error>) {
            self.continuation = continuation
        }

        func resume(_ result: Result<Data, Error>) {
            lock.lock()
            guard let continuation else {
                lock.unlock()
                return
            }
            self.continuation = nil
            lock.unlock()

            switch result {
            case .success(let data):
                continuation.resume(returning: data)
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
