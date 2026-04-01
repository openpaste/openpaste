import SwiftUI

struct ContentPreviewView: View {
    let item: ClipboardItem

    var body: some View {
        Group {
            switch item.type {
            case .text, .code, .richText:
                textPreview
            case .image:
                imagePreview
            case .link:
                linkPreview
            case .file:
                filePreview
            case .color:
                colorPreview
            }
        }
    }

    private var textPreview: some View {
        Text(item.plainTextContent?.truncated(to: 200) ?? "")
            .font(.system(.body, design: item.type == .code ? .monospaced : .default))
            .lineLimit(3)
            .foregroundStyle(.primary)
    }

    private var imagePreview: some View {
        Group {
            if let nsImage = NSImage(data: item.content) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Label("Image", systemImage: "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var linkPreview: some View {
        HStack {
            Image(systemName: "link")
                .foregroundStyle(.blue)
            Text(item.plainTextContent ?? "")
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.blue)
        }
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
