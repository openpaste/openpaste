import SwiftUI

struct PinboardTabBar: View {
    var collectionViewModel: CollectionViewModel?
    @Binding var selectedCollectionId: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                PinboardTab(
                    name: "All",
                    color: .accentColor,
                    isSelected: selectedCollectionId == nil,
                    onTap: { selectedCollectionId = nil }
                )

                if let cvm = collectionViewModel {
                    ForEach(cvm.collections) { collection in
                        PinboardTab(
                            name: collection.name,
                            color: Color(hex: collection.color),
                            isSelected: selectedCollectionId == collection.id,
                            onTap: { selectedCollectionId = collection.id }
                        )
                    }
                }
            }
        }
    }
}

private struct PinboardTab: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? color.opacity(0.15) : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? color.opacity(0.5) : Color(nsColor: .separatorColor),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}
