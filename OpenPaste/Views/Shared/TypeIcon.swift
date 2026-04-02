import SwiftUI

struct TypeIcon: View {
    let type: ContentType

    var body: some View {
        Image(systemName: systemName)
            .foregroundStyle(iconColor)
            .font(.system(size: 14))
            .frame(width: 24, height: 24)
    }

    private var systemName: String {
        switch type {
        case .text: "doc.text"
        case .richText: "doc.richtext"
        case .image: "photo"
        case .file: "doc"
        case .link: "link"
        case .color: "paintpalette"
        case .code: "chevron.left.forwardslash.chevron.right"
        }
    }

    private var iconColor: Color {
        switch type {
        case .text: .secondary
        case .richText: Color(nsColor: .systemBlue)
        case .image: Color(nsColor: .systemGreen)
        case .file: Color(nsColor: .systemOrange)
        case .link: Color(nsColor: .systemPurple)
        case .color: Color(nsColor: .systemPink)
        case .code: Color(nsColor: .systemTeal)
        }
    }
}
