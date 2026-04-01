import SwiftUI

struct TagFilterBar: View {
    let availableTags: [String]
    @Binding var selectedTags: [String]
    
    var body: some View {
        if !availableTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(availableTags, id: \.self) { tag in
                        FilterChip(
                            title: tag,
                            isActive: selectedTags.contains(tag)
                        ) {
                            if selectedTags.contains(tag) {
                                selectedTags.removeAll { $0 == tag }
                            } else {
                                selectedTags.append(tag)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
        }
    }
}
