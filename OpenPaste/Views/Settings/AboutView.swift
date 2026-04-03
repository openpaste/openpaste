import SwiftUI

struct AboutView: View {
    var updaterService: UpdaterServiceProtocol

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundStyle(DS.Colors.accent)

            Text("OpenPaste")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Open-source, local-first clipboard manager for developers")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Check for Updates…") {
                updaterService.checkForUpdates()
            }
            .disabled(!updaterService.canCheckForUpdates)

            Divider()

            HStack(spacing: 20) {
                Link("GitHub", destination: URL(string: "https://github.com/openpaste/openpaste") ?? URL(string: "https://github.com")!)
                Text("·").foregroundStyle(.tertiary)
                Text("AGPL-3.0 License")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
