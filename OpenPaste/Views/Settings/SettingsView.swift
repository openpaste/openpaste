import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gear") }

            PrivacySettingsView(viewModel: viewModel)
                .tabItem { Label("Privacy", systemImage: "lock.shield") }

            BlacklistView(viewModel: viewModel)
                .tabItem { Label("Blacklist", systemImage: "hand.raised") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 380)
    }
}
