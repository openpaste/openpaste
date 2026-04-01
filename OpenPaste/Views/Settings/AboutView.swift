import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("OpenPaste")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Open-source, privacy-first clipboard manager for macOS")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            HStack(spacing: 20) {
                Link("GitHub", destination: URL(string: "https://github.com/openpaste/openpaste")!)
                Text("•").foregroundStyle(.tertiary)
                Text("MIT License")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
