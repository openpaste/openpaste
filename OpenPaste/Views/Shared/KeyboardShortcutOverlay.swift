import SwiftUI

struct KeyboardShortcutOverlay: View {
    @Binding var isShowing: Bool
    @FocusState private var isFocused: Bool

    private let shortcuts: [(section: String, items: [(key: String, action: String)])] = [
        ("Navigation", [
            ("j / k", "Move down / up"),
            ("g g", "Go to top"),
            ("G", "Go to bottom"),
        ]),
        ("Actions", [
            ("Enter", "Paste selected"),
            ("Tab", "Toggle preview"),
            ("Escape", "Close panel"),
            ("/", "Focus search"),
            ("?", "This overlay"),
        ]),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { isShowing = false }

            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                HStack {
                    Image(systemName: "keyboard")
                    Text("Keyboard Shortcuts")
                        .font(.title3.bold())
                }
                .foregroundStyle(.primary)

                ForEach(shortcuts, id: \.section) { section in
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text(section.section)
                            .font(DS.Typography.sectionHeader)
                            .foregroundStyle(.secondary)

                        ForEach(section.items, id: \.key) { item in
                            HStack {
                                Text(item.key)
                                    .font(.system(.callout, design: .monospaced).bold())
                                    .frame(width: 80, alignment: .trailing)
                                    .foregroundStyle(DS.Colors.accent)
                                Text(item.action)
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                Text("Press any key to dismiss")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(DS.Spacing.xxl)
            .frame(width: 300)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .shadow(color: DS.Shadow.card.color, radius: 12)
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(phases: .down) { _ in
            isShowing = false
            return .handled
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .onAppear { isFocused = true }
    }
}
