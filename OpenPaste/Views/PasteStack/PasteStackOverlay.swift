import SwiftUI

struct PasteStackOverlay: View {
    @Bindable var viewModel: PasteStackViewModel

    var body: some View {
        if viewModel.isActive {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(.blue)

                if let current = viewModel.currentItem {
                    Text(current.plainTextContent?.truncated(to: 30) ?? current.type.rawValue)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(maxWidth: 150)
                }

                Text(viewModel.positionText)
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }
}
