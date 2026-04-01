import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onPaste: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onToggleStar: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TypeIcon(type: item.type)

            VStack(alignment: .leading, spacing: 2) {
                ContentPreviewView(item: item)

                HStack(spacing: 6) {
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
        .onTapGesture { onPaste() }
        .contextMenu {
            Button("Paste") { onPaste() }
            Divider()
            Button(item.pinned ? "Unpin" : "Pin") { onTogglePin() }
            Button(item.starred ? "Unstar" : "Star") { onToggleStar() }
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
