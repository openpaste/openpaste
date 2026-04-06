import SwiftUI

struct SmartListSidebarView: View {
    @Bindable var viewModel: SmartListViewModel
    var historyViewModel: HistoryViewModel?

    @State private var showEditor = false
    @State private var editingSmartList: SmartList?

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.smartLists.isEmpty {
                emptyState
            } else {
                listContent
            }

            Divider()
            addButton
        }
        .task {
            await viewModel.seedPresetsIfNeeded()
            await viewModel.loadSmartLists()
            await viewModel.refreshCounts()
        }
        .sheet(isPresented: $showEditor) {
            SmartListEditorView(
                smartList: editingSmartList,
                onSave: { smartList in
                    Task {
                        if editingSmartList != nil {
                            await viewModel.updateSmartList(smartList)
                        } else {
                            await viewModel.createSmartList(smartList)
                        }
                        await viewModel.refreshCounts()
                    }
                    showEditor = false
                    editingSmartList = nil
                },
                onCancel: {
                    showEditor = false
                    editingSmartList = nil
                }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No Smart Lists")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Create rules to automatically organize your clipboard")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var listContent: some View {
        List(selection: Binding(
            get: { viewModel.selectedSmartListId },
            set: { id in Task { await viewModel.selectSmartList(id) } }
        )) {
            // Built-in presets
            let builtIn = viewModel.smartLists.filter(\.isBuiltIn)
            if !builtIn.isEmpty {
                Section("Presets") {
                    ForEach(builtIn) { smartList in
                        smartListRow(smartList)
                    }
                }
            }

            // Custom smart lists
            let custom = viewModel.smartLists.filter { !$0.isBuiltIn }
            if !custom.isEmpty {
                Section("Custom") {
                    ForEach(custom) { smartList in
                        smartListRow(smartList)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func smartListRow(_ smartList: SmartList) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: smartList.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: smartList.color))
                .frame(width: 20)

            Text(smartList.name)
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer()

            if let count = viewModel.matchCounts[smartList.id] {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .separatorColor).opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .tag(smartList.id)
        .contextMenu {
            Button("Edit…") {
                editingSmartList = smartList
                showEditor = true
            }
            if !smartList.isBuiltIn {
                Button("Duplicate") {
                    Task { await duplicateSmartList(smartList) }
                }
                Divider()
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deleteSmartList(smartList.id) }
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            editingSmartList = nil
            showEditor = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                Text("New Smart List")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func duplicateSmartList(_ source: SmartList) async {
        var copy = SmartList(
            name: "\(source.name) Copy",
            icon: source.icon,
            color: source.color,
            rules: source.rules,
            isBuiltIn: false,
            position: viewModel.smartLists.count
        )
        copy.matchMode = source.matchMode
        copy.sortOrder = source.sortOrder
        await viewModel.createSmartList(copy)
    }
}
