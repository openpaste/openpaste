import SwiftUI

/// Async-loading thumbnail view that fetches image content on-demand via ThumbnailCache.
struct AsyncThumbnailView: View {
    let itemId: UUID
    var variant: ThumbnailCache.PreviewVariant = .card

    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.08))
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }
        }
        .task(id: itemId) {
            thumbnail = await ThumbnailCache.shared.loadThumbnailAsync(for: itemId, variant: variant)
        }
    }
}
