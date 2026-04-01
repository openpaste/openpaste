import SwiftUI

struct QuickEditView: View {
    let item: ClipboardItem
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var editedText: String = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Edit before pasting")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Paste") { onSave(editedText) }
                    .keyboardShortcut(.defaultAction)
            }

            TextEditor(text: $editedText)
                .font(.system(.body, design: item.type == .code ? .monospaced : .default))
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .frame(width: 500, height: 350)
        .onAppear {
            editedText = item.plainTextContent ?? ""
        }
    }
}
