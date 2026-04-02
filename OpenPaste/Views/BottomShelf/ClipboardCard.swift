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
        VStack(alignment: .leading, spacing: 6) {
            cardContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            HStack(spacing: 6) {
                if let icon = item.sourceApp.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 12, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                RelativeTimestamp(date: item.createdAt)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                statusBadges
            }
        }
        .padding(8)
        .frame(width: DS.Card.width, height: DS.Card.height)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Card.cornerRadius))
        .overlay(selectionBorder)
        .overlay(alignment: .topLeading) { typeIndicator }
        .overlay(alignment: .topTrailing) { quickIndexBadge }
        .scaleEffect(isHovered ? DS.Card.hoverScale : 1.0)
        .shadow(
            color: isSelected ? DS.Colors.accent.opacity(0.25) : DS.Shadow.card.color,
            radius: isSelected ? 8 : DS.Shadow.card.radius,
            x: DS.Shadow.card.x,
            y: DS.Shadow.card.y
        )
        .animation(DS.Animation.springSnappy, value: isHovered)
        .animation(DS.Animation.springSnappy, value: isSelected)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            onSelect()
            onPaste()
        }
        .contextMenu {
            Button("Paste") { onPaste() }
            Divider()
            Button(item.pinned ? "Unpin" : "Pin") { onTogglePin() }
            Button(item.starred ? "Unstar" : "Star") { onToggleStar() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: DS.Card.cornerRadius)
            .strokeBorder(
                isSelected ? DS.Colors.accent.opacity(DS.Card.selectedBorderOpacity) : Color(nsColor: .separatorColor),
                lineWidth: isSelected ? DS.Card.borderWidth : 0.5
            )
    }

    private var typeIndicator: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(typeColor)
            .frame(width: 3, height: 18)
            .padding(.top, 8)
            .padding(.leading, 4)
    }

    @ViewBuilder
    private var quickIndexBadge: some View {
        if let index, index < 9 {
            Text("⌘\(index + 1)")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(4)
                .opacity(isHovered ? 1 : 0.55)
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        switch item.type {
        case .text, .richText:
            sensitiveWrapper {
                Text(item.plainTextContent?.truncated(to: 120) ?? "")
                    .font(.system(size: 11))
                    .lineLimit(4)
                    .foregroundStyle(.primary)
            }
        case .code:
            sensitiveWrapper {
                SyntaxHighlightedCode(code: item.plainTextContent ?? "", maxLines: 4)
                    .font(.system(size: 10, design: .monospaced))
            }
        case .image:
            sensitiveWrapper {
                if let nsImage = NSImage(data: item.content) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .clipped()
                } else {
                    Label("Image", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .link:
            sensitiveWrapper {
                Text(item.plainTextContent?.truncated(to: 120) ?? "")
                    .font(.system(size: 10))
                    .lineLimit(4)
                    .foregroundStyle(.blue)
            }
        case .file:
            HStack(spacing: 6) {
                Image(systemName: "doc")
                    .foregroundStyle(.orange)
                Text(item.metadata["fileName"] ?? "File")
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }
        case .color:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: item.plainTextContent ?? "#000000"))
                    .frame(width: 26, height: 26)
                Text(item.plainTextContent ?? "")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private func sensitiveWrapper<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        if item.isSensitive {
            SensitiveContentOverlay { content() }
        } else {
            content()
        }
    }

    private var statusBadges: some View {
        HStack(spacing: 4) {
            if item.isSensitive {
                Image(systemName: "lock.shield")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if item.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            if item.starred {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
    }

    private var typeColor: Color {
        switch item.type {
        case .text: DS.Colors.text
        case .richText: DS.Colors.richText
        case .image: DS.Colors.image
        case .link: DS.Colors.link
        case .code: DS.Colors.code
        case .file: DS.Colors.file
        case .color: DS.Colors.colorType
        }
    }
}
