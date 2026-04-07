import SwiftUI

struct QuickEditView: View {
    let item: ClipboardItemSummary
    let onSave: (String) -> Void
    let onSaveImage: ((Data) -> Void)?
    let onCancel: () -> Void

    init(
        item: ClipboardItemSummary,
        onSave: @escaping (String) -> Void,
        onSaveImage: ((Data) -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.item = item
        self.onSave = onSave
        self.onSaveImage = onSaveImage
        self.onCancel = onCancel
    }

    @State private var editedText: String = ""
    @State private var showMarkdownPreview = false
    @State private var imageScale: CGFloat = 1.0
    @State private var cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var loadedImage: NSImage?

    private var uiTestImageScaleOverride: CGFloat? {
        #if DEBUG
            let env = ProcessInfo.processInfo.environment
            guard env["OPENPASTE_UI_TEST_MODE"] == "1",
                let raw = env["OPENPASTE_UI_TEST_IMAGE_SCALE"],
                let value = Double(raw)
            else { return nil }

            let clamped = min(max(CGFloat(value), 0.25), 2.0)
            return (clamped / 0.25).rounded() * 0.25
        #else
            nil
        #endif
    }

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
                    .accessibilityIdentifier("quickEdit.cancelButton")
                Button("Paste") {
                    if item.type == .image, let nsImage = loadedImage {
                        let data = ImageExport.exportTIFF(
                            image: nsImage, cropRect: cropRect, scale: imageScale)
                        if let onSaveImage {
                            onSaveImage(data)
                        } else {
                            onCancel()
                        }
                    } else {
                        onSave(editedText)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("quickEdit.pasteButton")
                .disabled(item.type == .image && onSaveImage == nil)
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
            if item.type == .image, let overrideScale = uiTestImageScaleOverride {
                imageScale = overrideScale
            }
        }
        .task {
            if item.type == .image {
                if let data = try? await ThumbnailCache.shared.storageService?.fetchContent(for: item.id) {
                    loadedImage = NSImage(data: data)
                }
            }
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
            if let nsImage = loadedImage {
                ImageCropView(image: nsImage, cropRect: $cropRect)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(maxHeight: 250)

                HStack {
                    Text("Scale: \(Int(imageScale * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("quickEdit.scaleLabel")
                    Slider(value: $imageScale, in: 0.25...2.0, step: 0.25)
                        .frame(width: 150)
                        .accessibilityIdentifier("quickEdit.scaleSlider")

                    Button("Reset") {
                        imageScale = 1.0
                        cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                    }
                    .controlSize(.small)
                    .accessibilityIdentifier("quickEdit.resetButton")
                }
            } else {
                ProgressView("Loading image…")
                    .frame(maxHeight: 250)
            }
        }
    }

    private var looksLikeMarkdown: Bool {
        let text = editedText
        return text.contains("# ") || text.contains("**") || text.contains("- ")
            || text.contains("```") || text.contains("[") && text.contains("](")
    }
}
