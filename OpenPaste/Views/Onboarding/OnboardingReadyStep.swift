import SwiftUI

struct OnboardingReadyStep: View {
    let viewModel: OnboardingViewModel
    @State private var checkmarks: [Bool] = [false, false, false, false]
    @State private var rocketScale: CGFloat = 0.5
    @State private var rocketOpacity: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            // Rocket icon
            Image(systemName: "paperplane.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.linearGradient(
                    colors: [.green, .mint],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .scaleEffect(rocketScale)
                .opacity(rocketOpacity)

            Text("You're All Set!")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("OpenPaste is ready to supercharge your clipboard.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Summary checklist
            VStack(alignment: .leading, spacing: 10) {
                summaryRow(index: 0, icon: "checkmark.circle.fill",
                          text: "Clipboard monitoring active",
                          color: .green)

                summaryRow(index: 1, icon: viewModel.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                          text: viewModel.accessibilityGranted ? "Accessibility permission granted" : "Accessibility permission pending",
                          color: viewModel.accessibilityGranted ? .green : .orange)

                summaryRow(index: 2, icon: "checkmark.circle.fill",
                          text: "Global shortcut: \(viewModel.hotkeyDisplayString)",
                          color: .green)

                summaryRow(index: 3, icon: "checkmark.circle.fill",
                          text: viewModel.launchAtLogin ? "Launch at login enabled" : "Launch at login disabled",
                          color: viewModel.launchAtLogin ? .green : .secondary)
            }
            .padding(.horizontal, 40)

            // Tip
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Press \(viewModel.hotkeyDisplayString) anytime to open clipboard history")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.08))
            )
        }
        .onAppear { animateEntrance() }
    }

    private func summaryRow(index: Int, icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .scaleEffect(checkmarks[index] ? 1.0 : 0.3)
                .opacity(checkmarks[index] ? 1.0 : 0)
            Text(text)
                .font(.callout)
                .opacity(checkmarks[index] ? 1.0 : 0)
                .offset(x: checkmarks[index] ? 0 : -10)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: checkmarks[index])
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            rocketScale = 1.0
            rocketOpacity = 1.0
        }
        for i in 0..<checkmarks.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.15) {
                checkmarks[i] = true
            }
        }
    }
}
