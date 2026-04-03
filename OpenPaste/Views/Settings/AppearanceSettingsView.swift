import SwiftUI

struct AppearanceSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    @AppStorage(Constants.appearanceThemeKey) private var theme = "system"
    @AppStorage(Constants.windowPositionModeKey) private var windowPosition = Constants.windowPositionModeBottomShelf

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $theme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.radioGroup)
            }

            Section("Window") {
                Picker("Open window", selection: $windowPosition) {
                    Text("Bottom Shelf (Paste-style)").tag(Constants.windowPositionModeBottomShelf)
                    Text("Center of screen").tag("center")
                    Text("Near cursor").tag("cursor")
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: theme) { _, newValue in
            applyAppearance(newValue)
        }
        .onAppear {
            applyAppearance(theme)
        }
    }

    private func applyAppearance(_ theme: String) {
        switch theme {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }
}
