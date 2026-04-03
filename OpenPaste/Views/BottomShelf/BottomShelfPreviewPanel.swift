import SwiftUI

struct BottomShelfPreviewPanel: View {
    let item: ClipboardItem
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                ContentPreviewView(item: item)
                    .padding(10)
            }
            Divider()
            metadata
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack(spacing: 8) {
            TypeIcon(type: item.type)
            Text(item.type.rawValue.capitalized)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            metadataRow("Source", value: item.sourceApp.name)
            metadataRow("Copied", value: item.createdAt.relativeFormatted)
            metadataRow("Size", value: item.content.humanReadableSize)
        }
        .padding(10)
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.primary)
        }
    }
}
