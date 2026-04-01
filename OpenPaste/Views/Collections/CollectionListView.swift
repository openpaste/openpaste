import SwiftUI

struct CollectionListView: View {
    @Bindable var viewModel: CollectionViewModel
    @State private var newCollectionName = ""
    @State private var showingAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.selectedCollection != nil {
                collectionItemsView
            } else {
                collectionsListView
            }
        }
        .task { await viewModel.loadCollections() }
        .sheet(isPresented: $showingAddSheet) { addCollectionSheet }
    }

    private var collectionsListView: some View {
        Group {
            if viewModel.collections.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.collections) { collection in
                        Button {
                            Task { await viewModel.selectCollection(collection) }
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(.blue)
                                Text(collection.name)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task { await viewModel.deleteCollection(collection.id) }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }

            HStack {
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Label("New Collection", systemImage: "plus")
                }
                .padding(8)
            }
        }
    }

    private var collectionItemsView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    viewModel.selectedCollection = nil
                    viewModel.collectionItems = []
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Text(viewModel.selectedCollection?.name ?? "")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if viewModel.collectionItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No items in this collection")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.collectionItems) { item in
                        HStack {
                            TypeIcon(type: item.type)
                            Text(item.plainTextContent?.truncated(to: 60) ?? item.type.rawValue)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                        }
                        .contextMenu {
                            Button("Remove from Collection") {
                                Task { await viewModel.removeItemFromCollection(item.id) }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No collections yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Create a collection to organize your clips")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addCollectionSheet: some View {
        VStack(spacing: 16) {
            Text("New Collection")
                .font(.headline)
            TextField("Collection name", text: $newCollectionName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            HStack {
                Button("Cancel") { showingAddSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    Task {
                        await viewModel.createCollection(name: newCollectionName)
                        newCollectionName = ""
                        showingAddSheet = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }
}
