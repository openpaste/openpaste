import SwiftUI

enum DS {
    // MARK: - Brand Colors
    enum Colors {
        static let accent = Color(red: 0.18, green: 0.77, blue: 0.71) // #2EC4B6
        static let secondary = Color(red: 0.38, green: 0.35, blue: 0.86) // #6159DB

        // Content-type accent colors
        static let text = Color.primary
        static let richText = Color.blue
        static let image = Color(red: 0.2, green: 0.78, blue: 0.35)
        static let file = Color.orange
        static let link = Color(red: 0.58, green: 0.39, blue: 0.87)
        static let colorType = Color.pink
        static let code = Color(red: 0.0, green: 0.75, blue: 0.83)
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
        static let card = (color: Color.black.opacity(0.08), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
    }

    // MARK: - Liquid Glass
    enum Glass {
        static let isAvailable = true
    }
}
