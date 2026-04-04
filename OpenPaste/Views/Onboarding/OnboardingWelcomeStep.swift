import SwiftUI

struct OnboardingWelcomeStep: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var featuresOpacity: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            // App icon with spring animation
            Image(systemName: "clipboard.fill")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

            // Title
            Text("Welcome to OpenPaste")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .offset(y: titleOffset)
                .opacity(titleOpacity)

            // Subtitle
            Text("Your local-first clipboard manager for macOS")
                .font(.title3)
                .foregroundColor(.secondary)
                .offset(y: subtitleOffset)
                .opacity(subtitleOpacity)

            // Feature highlights
            VStack(spacing: 12) {
                featureRow(icon: "magnifyingglass", title: "Fast Search", desc: "Find anything you've copied instantly")
                featureRow(icon: "lock.shield", title: "Local First", desc: "Your clipboard stays on your Mac by default")
                featureRow(icon: "keyboard", title: "Keyboard Driven", desc: "Power-user shortcuts for everything")
                featureRow(icon: "text.viewfinder", title: "OCR Built-in", desc: "Extract text from images automatically")
            }
            .padding(.top, 8)
            .opacity(featuresOpacity)
        }
        .onAppear { animateEntrance() }
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
            titleOffset = 0
            titleOpacity = 1.0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25)) {
            subtitleOffset = 0
            subtitleOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            featuresOpacity = 1.0
        }
    }
}
