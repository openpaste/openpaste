import SwiftUI

struct QuickEditView: View {
    let item: ClipboardItem
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var editedText: String = ""
    @State private var showMarkdownPreview = false
    @State private var imageScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Edit before pasting")
                    .font(.headline)
                Spacer()

                if item.type == .code || looksLikeMarkdown {
                    Toggle(isOn: $showMarkdownPreview) {
                        Image(systemName: "eye")
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .help("Toggle preview")
                }

                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Paste") { onSave(editedText) }
                    .keyboardShortcut(.defaultAction)
            }

            if item.type == .image {
                imageEditor
            } else if showMarkdownPreview && looksLikeMarkdown {
                markdownPreview
            } else if item.type == .code {
                codeEditor
            } else {
                textEditor
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear {
            editedText = item.plainTextContent ?? ""
        }
    }

    // MARK: - Text Editor

    private var textEditor: some View {
        TextEditor(text: $editedText)
            .font(.system(.body, design: .default))
            .frame(minHeight: 200)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Code Editor (with syntax highlighting header)

    private var codeEditor: some View {
        VStack(spacing: 0) {
            HStack {
                let lang = CodeLanguage.detect(from: editedText)
                Text(lang.rawValue.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            TextEditor(text: $editedText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)
                .padding(8)
        }
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Markdown Preview

    private var markdownPreview: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if let attributed = try? AttributedString(
                    markdown: editedText,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) {
                    Text(attributed)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(editedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
        }
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Image Editor (resize controls)

    private var imageEditor: some View {
        VStack(spacing: 8) {
            if let nsImage = NSImage(data: item.content) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(imageScale)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(maxHeight: 250)

                HStack {
                    Text("Scale: \(Int(imageScale * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $imageScale, in: 0.25...2.0, step: 0.25)
                        .frame(width: 150)

                    Button("Original") { imageScale = 1.0 }
                        .controlSize(.small)
                    Button("50%") { imageScale = 0.5 }
                        .controlSize(.small)
                }
            }
        }
    }

    private var looksLikeMarkdown: Bool {
        let text = editedText
        return text.contains("# ") || text.contains("**") || text.contains("- ") ||
               text.contains("```") || text.contains("[") && text.contains("](")
    }
}
