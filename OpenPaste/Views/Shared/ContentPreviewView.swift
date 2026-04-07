import SwiftUI

struct ContentPreviewView: View {
    let item: ClipboardItemSummary
    var highlightQuery: String = ""

    var body: some View {
        Group {
            switch item.type {
            case .text, .richText:
                sensitiveWrapper { textPreview }
            case .code:
                sensitiveWrapper { codePreview }
            case .image:
                sensitiveWrapper { imagePreview }
            case .link:
                sensitiveWrapper { linkPreview }
            case .file:
                filePreview
            case .color:
                colorPreview
            }
        }
    }

    // MARK: - Sensitive Content Blur

    @ViewBuilder
    private func sensitiveWrapper<Content: View>(@ViewBuilder content: @escaping () -> Content)
        -> some View
    {
        if item.isSensitive {
            SensitiveContentOverlay { content() }
        } else {
            content()
        }
    }

    // MARK: - Text Preview

    private var textPreview: some View {
        Group {
            if highlightQuery.isEmpty {
                Text(item.plainTextContent?.truncated(to: 200) ?? "")
                    .font(.system(.body, design: .default))
                    .lineLimit(3)
                    .foregroundStyle(.primary)
            } else {
                HighlightedText(
                    text: item.plainTextContent?.truncated(to: 200) ?? "",
                    highlight: highlightQuery,
                    design: .default
                )
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Code Preview (with syntax highlighting)

    private var codePreview: some View {
        Group {
            if highlightQuery.isEmpty {
                SyntaxHighlightedCode(
                    code: item.plainTextContent ?? "",
                    maxLines: 3
                )
            } else {
                HighlightedText(
                    text: item.plainTextContent?.truncated(to: 200) ?? "",
                    highlight: highlightQuery,
                    design: .monospaced
                )
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Image Preview

    private var imagePreview: some View {
        AsyncThumbnailView(itemId: item.id, variant: .list)
            .frame(maxHeight: 120)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Link Preview (with favicon + title)

    private var linkPreview: some View {
        LinkPreviewRow(
            urlString: item.plainTextContent ?? "",
            isSensitive: item.isSensitive
        )
    }

    private var filePreview: some View {
        HStack {
            Image(systemName: "doc")
                .foregroundStyle(.orange)
            VStack(alignment: .leading) {
                Text(item.metadata["fileName"] ?? "File")
                    .font(.caption)
                    .lineLimit(1)
                if let count = item.metadata["fileCount"], count != "1" {
                    Text("\(count) files")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var colorPreview: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: item.plainTextContent ?? "#000000"))
                .frame(width: 24, height: 24)
            Text(item.plainTextContent ?? "")
                .font(.system(.caption, design: .monospaced))
        }
    }
}

// MARK: - Sensitive Content Overlay (blur + reveal on hover)

struct SensitiveContentOverlay<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var isRevealed = false

    var body: some View {
        content()
            .blur(radius: isRevealed ? 0 : 8)
            .overlay {
                if !isRevealed {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                        Text("Hover to reveal")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
            }
            .onHover { hovering in
                withAnimation(DS.Animation.springDefault) {
                    isRevealed = hovering
                }
            }
            .contentShape(Rectangle())
    }
}

// MARK: - Link Preview Row (favicon + title fetching)

struct LinkPreviewRow: View {
    let urlString: String
    let isSensitive: Bool
    @State private var title: String?
    @State private var favicon: NSImage?
    @State private var didFetch = false

    var body: some View {
        HStack(spacing: 6) {
            if let fav = favicon {
                Image(nsImage: fav)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: "link")
                    .foregroundStyle(.blue)
                    .frame(width: 16, height: 16)
            }
            VStack(alignment: .leading, spacing: 1) {
                if let title = title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                Text(urlString)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.blue)
            }
        }
        .task {
            guard !didFetch,
                !isSensitive,
                (UserDefaults.standard.object(forKey: Constants.urlPreviewEnabledKey) as? Bool)
                    ?? true,
                let url = URL(string: urlString)
            else { return }
            didFetch = true
            if let metadata = await URLMetadataService.shared.fetch(url: url) {
                title = metadata.title
                if let data = metadata.favicon {
                    favicon = NSImage(data: data)
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
