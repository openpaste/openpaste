import AppKit
import SwiftUI

struct RunningAppPickerView: View {
    let onSelect: (AppInfo) -> Void
    let onCancel: () -> Void

    @State private var runningApps: [AppInfo] = []

    var body: some View {
        VStack {
            Text("Select App to Ignore")
                .font(.headline)
                .padding(.top)

            List(runningApps, id: \.bundleId) { app in
                Button {
                    onSelect(app)
                } label: {
                    HStack(spacing: 10) {
                        appIcon(for: app)
                        Text(app.name)
                        Spacer()
                        Text(app.bundleId)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(width: 400, height: 300)

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
            }
            .padding()
        }
        .onAppear { loadRunningApps() }
    }

    private func loadRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleId = app.bundleIdentifier else { return nil }
                return AppInfo(
                    bundleId: bundleId,
                    name: app.localizedName ?? bundleId,
                    iconPath: nil
                )
            }
            .sorted { $0.name < $1.name }
    }

    private func appIcon(for app: AppInfo) -> some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: app.bundleId
            ) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
        }
    }
}
