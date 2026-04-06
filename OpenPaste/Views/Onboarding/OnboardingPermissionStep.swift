import SwiftUI

struct OnboardingPermissionStep: View {
    let viewModel: OnboardingViewModel
    @State private var cardScale: CGFloat = 0.95
    @State private var cardOpacity: Double = 0
    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(viewModel.accessibilityGranted ? .green : .orange)
                .symbolEffect(
                    .pulse, options: .repeating, isActive: !viewModel.accessibilityGranted)

            Text("Accessibility Permission")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(
                "OpenPaste needs Accessibility access to capture global shortcuts and paste to other apps."
            )
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)

            // Status card
            statusCard
                .scaleEffect(cardScale)
                .opacity(cardOpacity)

            // Grant button or success
            if viewModel.accessibilityGranted {
                Label("Permission Granted", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: { viewModel.openAccessibilitySettings() }) {
                    Label("Open System Settings", systemImage: "gear")
                        .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if !viewModel.accessibilityGranted {
                Text(
                    "Click **+** in System Settings, then select **OpenPaste** from the Finder window."
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            }
        }
        .animation(
            .spring(response: 0.4, dampingFraction: 0.8), value: viewModel.accessibilityGranted
        )
        .onAppear {
            viewModel.startPermissionPolling()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
        }
        .onDisappear {
            viewModel.stopPermissionPolling()
        }
    }

    private var statusCard: some View {
        HStack(spacing: 16) {
            Image(
                systemName: viewModel.accessibilityGranted
                    ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
            )
            .font(.title2)
            .foregroundColor(viewModel.accessibilityGranted ? .green : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Accessibility Access")
                    .font(.headline)
                Text(
                    viewModel.accessibilityGranted
                        ? "OpenPaste is authorized"
                        : "Required for global shortcuts"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Circle()
                .fill(viewModel.accessibilityGranted ? Color.green : Color.orange)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(
                            viewModel.accessibilityGranted ? Color.green : Color.orange,
                            lineWidth: 2
                        )
                        .scaleEffect(pulseAnimation && !viewModel.accessibilityGranted ? 2.0 : 1.0)
                        .opacity(pulseAnimation && !viewModel.accessibilityGranted ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                            value: pulseAnimation)
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
        .padding(.horizontal, 20)
        .onAppear { pulseAnimation = true }
    }
}
