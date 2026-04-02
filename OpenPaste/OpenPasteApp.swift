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
    @AppStorage(Constants.appearanceThemeKey) private var theme = "system"

    var body: some Scene {
        MenuBarExtra("OpenPaste", systemImage: "clipboard") {
            if let error = controller.initError {
                Text("Error: \(error)")
            } else {
                Button("Show Clipboard History \(HotkeyManager.currentHotkeyDisplayString())") {
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
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultLaunchBehavior(.suppressed)
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Constants.appearanceThemeKey) ?? "system"
        DispatchQueue.main.async {
            switch saved {
            case "light": NSApp.appearance = NSAppearance(named: .aqua)
            case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
            default: NSApp.appearance = nil
            }
        }
    }
}
