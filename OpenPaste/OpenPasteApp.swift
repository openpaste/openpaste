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
        Settings {
            SettingsView(
                viewModel: controller.settingsViewModel,
                updaterService: controller.updaterService,
                feedbackRouter: controller.feedbackRouter
            )
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
