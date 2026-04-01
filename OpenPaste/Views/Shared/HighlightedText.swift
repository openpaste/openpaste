import SwiftUI

struct HighlightedText: View {
    let text: String
    let highlight: String
    var font: Font = .body
    var design: Font.Design = .default
    var lineLimit: Int = 3

    var body: some View {
        if highlight.isEmpty {
            Text(text)
                .font(.system(font == .body ? .body : .body, design: design))
                .lineLimit(lineLimit)
        } else {
            Text(makeAttributedString())
                .lineLimit(lineLimit)
        }
    }

    private func makeAttributedString() -> AttributedString {
        var attributed = AttributedString(text)
        let lowerText = text.lowercased()
        let lowerHighlight = highlight.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !lowerHighlight.isEmpty else { return attributed }

        let searchTokens = lowerHighlight.split(separator: " ").map(String.init)

        for token in searchTokens {
            var startIndex = lowerText.startIndex
            while startIndex < lowerText.endIndex,
                  let range = lowerText.range(of: token, range: startIndex..<lowerText.endIndex) {
                if let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
                   let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                    attributed[attrStart..<attrEnd].backgroundColor = .yellow.opacity(0.3)
                    attributed[attrStart..<attrEnd].font = .system(.body, design: design, weight: .semibold)
                }
                startIndex = range.upperBound
            }
        }
        return attributed
    }
}
