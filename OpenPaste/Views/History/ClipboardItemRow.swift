import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onPaste: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onToggleStar: () -> Void
    var onQuickEdit: (() -> Void)? = nil
    var onAddToStack: (() -> Void)? = nil
    var highlightQuery: String = ""

    var body: some View {
        HStack(spacing: 10) {
            TypeIcon(type: item.type)

            VStack(alignment: .leading, spacing: 2) {
                if highlightQuery.isEmpty {
                    ContentPreviewView(item: item)
                } else {
                    ContentPreviewView(item: item, highlightQuery: highlightQuery)
                }

                HStack(spacing: 6) {
                    if let icon = item.sourceApp.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 12, height: 12)
                    }
                    if !item.sourceApp.name.isEmpty && item.sourceApp.name != "Unknown" {
                        Text(item.sourceApp.name)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    RelativeTimestamp(date: item.createdAt)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                if item.isSensitive {
                    Image(systemName: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if item.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                if item.starred {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .hoverHighlight()
        .draggable(item.id.uuidString)
        .onTapGesture { onPaste() }
        .contextMenu {
            Button("Paste") { onPaste() }
            if onQuickEdit != nil {
                Button("Quick Edit…") { onQuickEdit?() }
            }
            Divider()
            Button(item.pinned ? "Unpin" : "Pin") { onTogglePin() }
            Button(item.starred ? "Unstar" : "Star") { onToggleStar() }
            if let onAddToStack {
                Divider()
                Button("Add to Paste Stack") { onAddToStack() }
            }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let typeText = item.type.rawValue
        let content = item.plainTextContent?.truncated(to: 50) ?? typeText
        return "\(typeText): \(content)"
    }
}
