import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gear") }

            PrivacySettingsView(viewModel: viewModel)
                .tabItem { Label("Privacy", systemImage: "lock.shield") }

            ShortcutsSettingsView(viewModel: viewModel)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 460)
    }
}
