import SwiftUI

struct HoverHighlightModifier: ViewModifier {
    @State private var isHovered = false
    var cornerRadius: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
            )
            .onHover { hovering in
                withAnimation(DS.Animation.quick) {
                    isHovered = hovering
                }
            }
    }
}

extension View {
    func hoverHighlight(cornerRadius: CGFloat = 6) -> some View {
        modifier(HoverHighlightModifier(cornerRadius: cornerRadius))
    }
}
