import Foundation
import Testing

@testable import OpenPaste

@Suite
struct ConflictResolverTests {
    private func encodeJSON<T: Encodable>(_ value: T) -> String {
        let data = (try? JSONEncoder().encode(value)) ?? Data()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func makeItem(
        id: String = UUID().uuidString,
        content: String,
        modifiedAt: Date,
        tags: [String] = [],
        pinned: Bool = false,
        starred: Bool = false,
        accessCount: Int = 0,
        metadata: [String: String] = [:]
    ) -> ClipboardItemRecord {
        ClipboardItemRecord(
            id: id,
            type: ContentType.text.rawValue,
            content: Data(content.utf8),
            plainTextContent: content,
            ocrText: nil,
            sourceAppBundleId: "",
            sourceAppName: "Unknown",
            sourceAppIconPath: nil,
            sourceURL: nil,
            createdAt: modifiedAt.addingTimeInterval(-10),
            modifiedAt: modifiedAt,
            deviceId: "device",
            isDeleted: false,
            syncVersion: 1,
            ckSystemFields: nil,
            accessedAt: modifiedAt,
            accessCount: accessCount,
            tags: encodeJSON(tags),
            pinned: pinned,
            starred: starred,
            collectionId: nil,
            contentHash: "hash",
            isSensitive: false,
            expiresAt: nil,
            metadata: encodeJSON(metadata)
        )
    }

    @Test
    func remoteWinsForContentWhenModifiedAtNewer() {
        let base = Date()
        let local = makeItem(content: "local", modifiedAt: base)
        let remote = makeItem(
            id: local.id, content: "remote", modifiedAt: base.addingTimeInterval(5))

        let merged = ConflictResolver.resolve(local: local, remote: remote)
        #expect(String(data: merged.content, encoding: .utf8) == "remote")
        #expect(merged.modifiedAt == remote.modifiedAt)
    }

    @Test
    func tagsAreUnionMerged() {
        let base = Date()
        let local = makeItem(content: "a", modifiedAt: base, tags: ["one", "two"])
        let remote = makeItem(
            id: local.id, content: "b", modifiedAt: base.addingTimeInterval(1),
            tags: ["two", "three"])

        let merged = ConflictResolver.resolve(local: local, remote: remote)
        let decoded = (try? JSONDecoder().decode([String].self, from: Data(merged.tags.utf8))) ?? []
        #expect(Set(decoded) == Set(["one", "two", "three"]))
    }

    @Test
    func pinnedAndStarredUseLWW() {
        let base = Date()
        let local = makeItem(content: "a", modifiedAt: base, pinned: true, starred: false)
        let remote = makeItem(
            id: local.id, content: "b", modifiedAt: base.addingTimeInterval(1), pinned: false,
            starred: true)

        // Remote wins (newer modifiedAt), so remote's values take precedence
        let merged = ConflictResolver.resolve(local: local, remote: remote)
        #expect(merged.pinned == false)
        #expect(merged.starred == true)

        // Verify local wins when it's newer
        let local2 = makeItem(
            content: "a", modifiedAt: base.addingTimeInterval(2), pinned: true, starred: false)
        let merged2 = ConflictResolver.resolve(local: local2, remote: remote)
        #expect(merged2.pinned == true)
        #expect(merged2.starred == false)
    }

    @Test
    func accessCountKeepsMax() {
        let base = Date()
        let local = makeItem(content: "a", modifiedAt: base, accessCount: 10)
        let remote = makeItem(
            id: local.id, content: "b", modifiedAt: base.addingTimeInterval(1), accessCount: 3)

        let merged = ConflictResolver.resolve(local: local, remote: remote)
        #expect(merged.accessCount == 10)
    }

    @Test
    func metadataMergePrefersWinner() {
        let base = Date()
        let local = makeItem(content: "a", modifiedAt: base, metadata: ["k": "local", "keep": "x"])
        let remote = makeItem(
            id: local.id, content: "b", modifiedAt: base.addingTimeInterval(1),
            metadata: ["k": "remote"])  // remote wins

        let merged = ConflictResolver.resolve(local: local, remote: remote)
        let decoded =
            (try? JSONDecoder().decode([String: String].self, from: Data(merged.metadata.utf8)))
            ?? [:]
        #expect(decoded["k"] == "remote")
        #expect(decoded["keep"] == "x")
    }

    @Test
    func collectionRemoteWinsForNameColor() {
        let base = Date()
        let local = CollectionRecord(
            id: UUID().uuidString,
            name: "Local",
            color: "#000000",
            createdAt: base.addingTimeInterval(-10),
            modifiedAt: base,
            deviceId: "a",
            isDeleted: false,
            ckSystemFields: nil
        )
        let remote = CollectionRecord(
            id: local.id,
            name: "Remote",
            color: "#FFFFFF",
            createdAt: local.createdAt,
            modifiedAt: base.addingTimeInterval(5),
            deviceId: "b",
            isDeleted: false,
            ckSystemFields: nil
        )

        let merged = ConflictResolver.resolve(local: local, remote: remote)
        #expect(merged.name == "Remote")
        #expect(merged.color == "#FFFFFF")
    }
}
