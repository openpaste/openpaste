import SwiftUI

struct ShortcutHintBar: View {
    var body: some View {
        HStack(spacing: 16) {
            hintItem("↵", "Paste")
            hintItem("⇧↵", "Plain Text")
            hintItem("⇥ / Space", "Preview")
            hintItem("⌘1-9", "Quick Paste")
            hintItem("Drag", "To App")
                .accessibilityIdentifier("bottomShelf.hint.dragToApp")
                .accessibilityLabel("Drag To App")
            Spacer()
        }
        .padding(.horizontal, DS.Shelf.horizontalPadding)
        .padding(.vertical, 5)
        .frame(height: DS.Shelf.hintBarHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bottomShelf.hintBar")
        // Blur handled by NSVisualEffectView at panel level — no extra material needed
    }

    private func hintItem(_ key: String, _ action: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Colors.accent)
            Text(action)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}
