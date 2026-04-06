//
//  NewTextItemWindow.swift
//  OpenPaste
//

import AppKit
import SwiftUI

@MainActor
final class NewTextItemWindow {
    private var panel: NSPanel?
    private let storageService: StorageServiceProtocol

    init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }

    func show() {
        if let existing = panel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let view = NewTextItemView(
            onSave: { [weak self] text in
                self?.saveItem(text: text)
                self?.close()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 250)

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.title = "New Text Item"
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.center()
        newPanel.contentView = hostingView
        newPanel.isReleasedWhenClosed = false

        newPanel.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        panel = newPanel
    }

    func close() {
        panel?.close()
        panel = nil
    }

    private func saveItem(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let data = Data(text.utf8)
        let hash = ContentHasher().hash(data)
        let item = ClipboardItem(
            type: .text,
            content: data,
            plainTextContent: text,
            sourceApp: AppInfo(
                bundleId: Constants.bundleIdentifier,
                name: Constants.appName,
                iconPath: nil
            ),
            contentHash: hash
        )
        Task {
            do {
                try await storageService.save(item)
            } catch {
                NSLog("Failed to save text item: \(error)")
            }
        }
    }
}

// MARK: - SwiftUI View for the Panel

private struct NewTextItemView: View {
    @State private var text = ""
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("New Text Item")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") { onSave(text) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 250)
    }
}
