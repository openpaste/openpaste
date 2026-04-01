//
//  OpenPasteApp.swift
//  OpenPaste
//
//  Created by Lê Anh Tuấn on 1/4/26.
//

import SwiftUI

@main
struct OpenPasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var controller = AppController()

    var body: some Scene {
        MenuBarExtra("OpenPaste", systemImage: "clipboard") {
            if let error = controller.initError {
                Text("Error: \(error)")
            } else {
                Button("Show Clipboard History ⇧⌘V") {
                    controller.togglePanel()
                }
                .keyboardShortcut("v", modifiers: [.shift, .command])

                Divider()

                SettingsLink {
                    Text("Settings…")
                }
                .keyboardShortcut(",", modifiers: .command)

                Divider()

                Button("Quit OpenPaste") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(viewModel: controller.settingsViewModel)
        }
    }
}
