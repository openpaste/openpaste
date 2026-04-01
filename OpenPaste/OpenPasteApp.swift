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
    @State private var container: DependencyContainer?
    @State private var windowManager = WindowManager()
    @State private var hotkeyManager: HotkeyManager?
    @State private var historyViewModel: HistoryViewModel?
    @State private var searchViewModel: SearchViewModel?
    @State private var settingsViewModel = SettingsViewModel()
    @State private var initError: String?

    var body: some Scene {
        MenuBarExtra("OpenPaste", systemImage: "clipboard") {
            if let initError {
                Text("Error: \(initError)")
            } else {
                Button("Show Clipboard History ⇧⌘V") {
                    togglePanel()
                }
                .keyboardShortcut("v", modifiers: [.shift, .command])

                Divider()

                Button("Settings…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
            SettingsView(viewModel: settingsViewModel)
        }
    }

    private func setupIfNeeded() {
        guard container == nil else { return }
        do {
            let c = try DependencyContainer()
            container = c

            let hvm = HistoryViewModel(
                storageService: c.storageService,
                clipboardService: c.clipboardService,
                eventBus: c.eventBus
            )
            historyViewModel = hvm

            let svm = SearchViewModel(searchService: c.searchService)
            searchViewModel = svm

            let hk = HotkeyManager { [weak windowManager] in
                windowManager?.toggle {
                    ContentView(historyViewModel: hvm, searchViewModel: svm)
                }
            }
            hotkeyManager = hk

            Task {
                await hk.register()
                await c.clipboardService.startMonitoring()
            }
        } catch {
            initError = error.localizedDescription
        }
    }

    private func togglePanel() {
        setupIfNeeded()
        guard let hvm = historyViewModel, let svm = searchViewModel else { return }
        windowManager.toggle {
            ContentView(historyViewModel: hvm, searchViewModel: svm)
        }
    }
}
