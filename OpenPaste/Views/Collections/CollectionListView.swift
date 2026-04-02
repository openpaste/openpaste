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
                                    .foregroundStyle(DS.Colors.accent)
                                Text(collection.name)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .hoverHighlight()
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task { await viewModel.deleteCollection(collection.id) }
                            }
                        }
                        // Accept drops of clipboard items into this collection
                        .dropDestination(for: String.self) { droppedIds, _ in
                            for idStr in droppedIds {
                                guard let uuid = UUID(uuidString: idStr) else { continue }
                                Task { await viewModel.assignItem(uuid, toCollection: collection.id) }
                            }
                            return true
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
                    Text("Drag items here to organize")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
                        .draggable(item.id.uuidString)
                        .contextMenu {
                            Button("Remove from Collection") {
                                Task { await viewModel.removeItemFromCollection(item.id) }
                            }
                        }
                    }
                    .onMove { source, destination in
                        viewModel.collectionItems.move(fromOffsets: source, toOffset: destination)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(DS.Colors.accent.opacity(0.6))
                .symbolEffect(.pulse.byLayer, options: .repeating)

            Text("No collections yet")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text("Create a collection to organize your clips")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
