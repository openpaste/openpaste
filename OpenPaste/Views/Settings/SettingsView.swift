import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    var updaterService: UpdaterServiceProtocol

    @State private var selectedSection: SettingsSection = .general

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general, privacy, keyboard, appearance, storage, about

        var id: String { rawValue }

        var title: String { rawValue.capitalized }

        var icon: String {
            switch self {
            case .general: "gear"
            case .privacy: "lock.shield"
            case .keyboard: "keyboard"
            case .appearance: "paintbrush"
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
            case .storage:
                StorageSettingsView(viewModel: viewModel)
            case .about:
                AboutView(updaterService: updaterService)
            }
        }
        .frame(width: 650, height: 480)
    }
}
