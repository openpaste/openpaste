import SwiftUI

struct OnboardingPreferencesStep: View {
    let viewModel: OnboardingViewModel
    @State private var cardsVisible = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.linearGradient(
                    colors: [.purple, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Quick Setup")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("Configure essential preferences. You can change these later in Settings.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // Settings cards
            VStack(spacing: 12) {
                settingCard(
                    icon: "power",
                    title: "Launch at Login",
                    description: "Start OpenPaste automatically when you log in",
                    toggle: Binding(
                        get: { viewModel.launchAtLogin },
                        set: { viewModel.launchAtLogin = $0 }
                    )
                )

                infoCard(
                    icon: "eye.slash",
                    title: "Privacy Protection",
                    description: "Sensitive content (API keys, passwords) is auto-detected and flagged",
                    badge: "Enabled"
                )

                infoCard(
                    icon: "doc.on.clipboard",
                    title: "Clipboard Monitoring",
                    description: "Watches for new clipboard content every 500ms",
                    badge: "Active"
                )
            }
            .opacity(cardsVisible ? 1 : 0)
            .offset(y: cardsVisible ? 0 : 15)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                cardsVisible = true
            }
        }
    }

    private func settingCard(icon: String, title: String, description: String, toggle: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: toggle)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        )
        .padding(.horizontal, 20)
    }

    private func infoCard(icon: String, title: String, description: String, badge: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(badge)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.15))
                .foregroundColor(.green)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        )
        .padding(.horizontal, 20)
    }
}
