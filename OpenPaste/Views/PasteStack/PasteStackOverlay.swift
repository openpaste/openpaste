import SwiftUI

struct PasteStackOverlay: View {
    @Bindable var viewModel: PasteStackViewModel

    var body: some View {
        if viewModel.isActive {
            VStack(spacing: 0) {
                // Stack items with drag-and-drop reorder
                if viewModel.items.count > 1 {
                    List {
                        ForEach(viewModel.items) { item in
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                TypeIcon(type: item.type)
                                    .scaleEffect(0.8)
                                Text(item.plainTextContent?.truncated(to: 30) ?? item.type.rawValue)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer()
                                if item.id == viewModel.currentItem?.id {
                                    Image(systemName: "arrowtriangle.right.fill")
                                        .font(.caption2)
                                        .foregroundStyle(DS.Colors.accent)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .onMove { source, destination in
                            viewModel.moveItems(from: source, to: destination)
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: min(CGFloat(viewModel.items.count) * 28, 120))
                }

                // Action bar
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundStyle(DS.Colors.accent)

                    if let current = viewModel.currentItem {
                        Text(current.plainTextContent?.truncated(to: 30) ?? current.type.rawValue)
                            .font(.caption)
                            .lineLimit(1)
                            .frame(maxWidth: 150)
                    }

                    Text(viewModel.positionText)
                        .font(.caption.bold())
                        .foregroundStyle(DS.Colors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DS.Colors.accent.opacity(0.1))
                        .clipShape(Capsule())

                    Button("Paste Next") {
                        Task { await viewModel.pasteNext() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        viewModel.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear stack (⇧⌘⌫)")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
            .overlay {
                // Hidden button for clear shortcut: ⇧⌘⌫
                Button("") { viewModel.clear() }
                    .keyboardShortcut(.delete, modifiers: [.shift, .command])
                    .frame(width: 0, height: 0)
                    .opacity(0)
            }
        }
    }
}
