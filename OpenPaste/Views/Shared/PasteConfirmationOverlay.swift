import SwiftUI

struct PasteConfirmationOverlay: View {
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: isShowing)

                Text("Pasted!")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .opacity
            ))
            .task {
                try? await Task.sleep(for: .milliseconds(800))
                withAnimation(DS.Animation.springDefault) {
                    isShowing = false
                }
            }
        }
    }
}
