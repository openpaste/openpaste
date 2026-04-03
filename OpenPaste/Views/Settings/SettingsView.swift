import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    var updaterService: UpdaterServiceProtocol
    var feedbackRouter: FeedbackRouterProtocol

    @State private var selectedSection: SettingsSection = .general

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general, privacy, keyboard, appearance, sync, storage, about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: "General"
            case .privacy: "Privacy"
            case .keyboard: "Keyboard"
            case .appearance: "Appearance"
            case .sync: "Sync (Premium Beta)"
            case .storage: "Storage"
            case .about: "About"
            }
        }

        var icon: String {
            switch self {
            case .general: "gear"
            case .privacy: "lock.shield"
            case .keyboard: "keyboard"
            case .appearance: "paintbrush"
            case .sync: "icloud"
            case .storage: "internaldrive"
            case .about: "info.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            switch selectedSection {
            case .general:
                GeneralSettingsView(viewModel: viewModel, updaterService: updaterService)
            case .privacy:
                PrivacySettingsView(viewModel: viewModel)
            case .keyboard:
                ShortcutsSettingsView(viewModel: viewModel)
            case .appearance:
                AppearanceSettingsView(viewModel: viewModel)
            case .sync:
                SyncSettingsView(viewModel: viewModel)
            case .storage:
                StorageSettingsView(viewModel: viewModel)
            case .about:
                AboutView(updaterService: updaterService, feedbackRouter: feedbackRouter)
            }
        }
        .frame(width: 650, height: 480)
    }
}
