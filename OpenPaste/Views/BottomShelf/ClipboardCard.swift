import AppKit
import SwiftUI

struct ClipboardCard: View {
    let item: ClipboardItem
    let isSelected: Bool
    var index: Int?

    let onPaste: () -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onToggleStar: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: handlePrimaryClick) {
            cardBody
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Paste") { onPaste() }
            Divider()
            Button(item.pinned ? "Unpin" : "Pin") { onTogglePin() }
            Button(item.starred ? "Unstar" : "Star") { onToggleStar() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Type badge header
            typeBadge
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Content preview area
            cardContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 10)

            Spacer(minLength: 0)

            // Footer with metadata
            Divider()
                .padding(.horizontal, 6)

            cardFooter
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .frame(width: DS.Card.width, height: DS.Card.height)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Card.cornerRadius))
        .overlay(selectionBorder)
        .overlay(alignment: .topTrailing) { quickIndexBadge }
        .scaleEffect(isHovered ? DS.Card.hoverScale : 1.0)
        .shadow(
            color: isSelected ? DS.Colors.accent.opacity(0.3) : DS.Shadow.card.color,
            radius: isSelected ? 10 : DS.Shadow.card.radius,
            x: DS.Shadow.card.x,
            y: DS.Shadow.card.y
        )
        .animation(DS.Animation.springSnappy, value: isHovered)
        .animation(DS.Animation.springSnappy, value: isSelected)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private func handlePrimaryClick() {
        onSelect()

        guard let event = NSApp.currentEvent,
              event.type == .leftMouseUp,
              event.clickCount == 2 else {
            return
        }

        onPaste()
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DS.Card.cornerRadius)
            .fill(
                isSelected
                    ? Color(nsColor: .controlBackgroundColor).opacity(0.82)
                    : Color(nsColor: .controlBackgroundColor).opacity(0.72)
            )
    }

    // MARK: - Selection Border

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: DS.Card.cornerRadius)
            .strokeBorder(
                isSelected
                    ? DS.Colors.accent.opacity(DS.Card.selectedBorderOpacity)
                    : Color(nsColor: .separatorColor).opacity(0.4),
                lineWidth: isSelected ? DS.Card.borderWidth : 0.5
            )
    }

    // MARK: - Type Badge (Paste-style: filled color + white text)

    private var typeBadge: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: typeIcon)
                    .font(.system(size: 8, weight: .bold))
                Text(typeName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(typeColor)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            statusBadges

            Spacer(minLength: 0)
        }
    }

    // MARK: - Quick Index Badge (⌘1-9)

    @ViewBuilder
    private var quickIndexBadge: some View {
        if let index, index < 9 {
            Text("⌘\(index + 1)")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(6)
                .opacity(isHovered ? 1 : 0)
                .animation(DS.Animation.quick, value: isHovered)
        }
    }

    // MARK: - Card Content (rich preview)

    @ViewBuilder
    private var cardContent: some View {
        switch item.type {
        case .text, .richText:
            sensitiveWrapper {
                Text(item.plainTextContent?.truncated(to: 200) ?? "")
                    .font(.system(size: 12))
                    .lineLimit(6)
                    .foregroundStyle(.primary)
            }
        case .code:
            sensitiveWrapper {
                SyntaxHighlightedCode(code: item.plainTextContent ?? "", maxLines: 6)
                    .font(.system(size: 11, design: .monospaced))
            }
        case .image:
            sensitiveWrapper {
                if let nsImage = ThumbnailCache.shared.thumbnail(for: item.id, data: item.content) {
                    GeometryReader { geo in
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .clipped()
                    }
                } else {
                    Label("Image", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .link:
            sensitiveWrapper {
                VStack(alignment: .leading, spacing: 4) {
                    if let urlStr = item.plainTextContent,
                       let url = URL(string: urlStr),
                       let host = url.host {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 9))
                                .foregroundStyle(.blue)
                            Text(host)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.blue)
                                .lineLimit(1)
                        }
                    }
                    Text(item.plainTextContent?.truncated(to: 140) ?? "")
                        .font(.system(size: 11))
                        .lineLimit(4)
                        .foregroundStyle(.blue.opacity(0.8))
                }
            }
        case .file:
            HStack(spacing: 6) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 16))
                Text(item.metadata["fileName"] ?? "File")
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }
        case .color:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: item.plainTextContent ?? "#000000"))
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                Text(item.plainTextContent ?? "")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Card Footer (app icon + timestamp + metadata)

    private var cardFooter: some View {
        HStack(spacing: 4) {
            if let icon = item.sourceApp.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 12, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            RelativeTimestamp(date: item.createdAt)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 2)

            metadataText
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    // MARK: - Metadata Text (dimensions/char count)

    private var metadataText: some View {
        Group {
            switch item.type {
            case .image:
                if let nsImage = NSImage(data: item.content) {
                    Text("\(Int(nsImage.size.width)) × \(Int(nsImage.size.height))")
                }
            case .text, .richText, .code:
                if let text = item.plainTextContent {
                    Text("\(text.count) characters")
                }
            case .link:
                if let text = item.plainTextContent {
                    Text("\(text.count) characters")
                }
            case .file:
                Text(item.content.humanReadableSize)
            case .color:
                EmptyView()
            }
        }
    }

    // MARK: - Status Badges

    private var statusBadges: some View {
        HStack(spacing: 3) {
            if item.isSensitive {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
            }
            if item.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.blue)
            }
            if item.starred {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.yellow)
            }
        }
    }

    // MARK: - Sensitive Wrapper

    @ViewBuilder
    private func sensitiveWrapper<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        if item.isSensitive {
            SensitiveContentOverlay { content() }
        } else {
            content()
        }
    }

    // MARK: - Type Helpers

    private var typeName: String {
        switch item.type {
        case .text: "Text"
        case .richText: "Text"
        case .image: "Image"
        case .link: "Link"
        case .code: "Code"
        case .file: "File"
        case .color: "Color"
        }
    }

    private var typeIcon: String {
        switch item.type {
        case .text: "text.alignleft"
        case .richText: "text.alignleft"
        case .image: "photo"
        case .link: "link"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .file: "doc.fill"
        case .color: "paintpalette.fill"
        }
    }

    private var typeColor: Color {
        switch item.type {
        case .text: DS.Colors.richText       // Blue
        case .richText: DS.Colors.richText   // Blue
        case .image: DS.Colors.image         // Green
        case .link: DS.Colors.link           // Purple
        case .code: DS.Colors.code           // Teal
        case .file: DS.Colors.file           // Orange
        case .color: DS.Colors.colorType     // Pink
        }
    }
}
