import SwiftUI

enum DS {
    // MARK: - Brand Colors (native adaptive)
    enum Colors {
        /// Uses the AccentColor defined in Asset Catalog — auto-adapts light/dark
        static let accent = Color.accentColor

        /// System semantic colors — no hardcoding needed
        static let secondary = Color.secondary

        // Content-type colors — use system semantic colors that adapt automatically
        static let text = Color.primary
        static let richText = Color(nsColor: .systemBlue)
        static let image = Color(nsColor: .systemGreen)
        static let file = Color(nsColor: .systemOrange)
        static let link = Color(nsColor: .systemPurple)
        static let colorType = Color(nsColor: .systemPink)
        static let code = Color(nsColor: .systemCyan)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
    }

    // MARK: - Corner Radii
    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
    }

    // MARK: - Card (Bottom Shelf)
    enum Card {
        static let width: CGFloat = 200
        static let height: CGFloat = 180
        static let spacing: CGFloat = 12
        static let cornerRadius: CGFloat = 12
        static let borderWidth: CGFloat = 2
        static let hoverScale: CGFloat = 1.05
        static let selectedBorderOpacity: Double = 0.85
        static let typeBadgeHeight: CGFloat = 24
        static let imagePreviewHeight: CGFloat = 96
    }

    // MARK: - Bottom Shelf
    enum Shelf {
        static let defaultHeight: CGFloat = 300
        static let minHeight: CGFloat = 200
        static let maxHeight: CGFloat = 400
        static let searchBarHeight: CGFloat = 36
        static let tabBarHeight: CGFloat = 32
        static let hintBarHeight: CGFloat = 24
        static let horizontalPadding: CGFloat = 16
        static let edgeInset: CGFloat = 12
        static let cornerRadius: CGFloat = 14
    }

    // MARK: - Animation
    enum Animation {
        static let springDefault = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
        static let springSnappy = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.75)
        static let springGentle = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.85)
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
    }

    // MARK: - Typography
    enum Typography {
        static let rowTitle = Font.system(.body, design: .default)
        static let rowMeta = Font.caption2
        static let codePreview = Font.system(.caption, design: .monospaced)
        static let filterChip = Font.caption.weight(.medium)
        static let sectionHeader = Font.caption.weight(.semibold)
    }

    // MARK: - Shadows
    enum Shadow {
        static let card = (
            color: Color.black.opacity(0.08), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2)
        )
    }

    // MARK: - Liquid Glass
    enum Glass {
        static let isAvailable = true
    }
}
