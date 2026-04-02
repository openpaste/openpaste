import SwiftUI

struct TypeIcon: View {
    let type: ContentType

    var body: some View {
        Image(systemName: systemName)
            .foregroundStyle(iconColor)
            .font(.system(size: 18))
            .frame(width: 28, height: 28)
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
        case .text: DS.Colors.text
        case .richText: DS.Colors.richText
        case .image: DS.Colors.image
        case .file: DS.Colors.file
        case .link: DS.Colors.link
        case .color: DS.Colors.colorType
        case .code: DS.Colors.code
        }
    }
}
