import Foundation

@Observable
final class CollectionViewModel {
    var collections: [Collection] = []
    var selectedCollection: Collection?
    var collectionItems: [ClipboardItem] = []

    private let storageService: StorageServiceProtocol

    init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }

    func loadCollections() async {
        collections = (try? await storageService.fetchCollections()) ?? []
    }

    func createCollection(name: String) async {
        let collection = Collection(name: name)
        try? await storageService.saveCollection(collection)
        await loadCollections()
    }

    func deleteCollection(_ id: UUID) async {
        try? await storageService.deleteCollection(id)
        if selectedCollection?.id == id {
            selectedCollection = nil
            collectionItems = []
        }
        await loadCollections()
    }

    func selectCollection(_ collection: Collection) async {
        selectedCollection = collection
        collectionItems = (try? await storageService.fetchItems(inCollection: collection.id)) ?? []
    }

    func assignItem(_ itemId: UUID, toCollection collectionId: UUID) async {
        try? await storageService.assignItemToCollection(itemId: itemId, collectionId: collectionId)
        if let sel = selectedCollection, sel.id == collectionId {
            await selectCollection(sel)
        }
        await loadCollections()
    }

    func removeItemFromCollection(_ itemId: UUID) async {
        try? await storageService.assignItemToCollection(itemId: itemId, collectionId: nil)
        if let sel = selectedCollection {
            await selectCollection(sel)
        }
    }
}
