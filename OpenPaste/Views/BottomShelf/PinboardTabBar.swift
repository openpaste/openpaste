import SwiftUI

struct PinboardTabBar: View {
    var collectionViewModel: CollectionViewModel?
    @Binding var selectedCollectionId: UUID?
    var onAddCollection: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    PinboardTab(
                        name: "Clipboard History",
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

            // Add collection button
            if onAddCollection != nil {
                Button(action: { onAddCollection?() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color(nsColor: .separatorColor).opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("New Pinboard")
            }
        }
    }
}

private struct PinboardTab: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? color.opacity(0.15)
                    : (isHovered ? Color(nsColor: .separatorColor).opacity(0.15) : Color.clear)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
        .animation(DS.Animation.quick, value: isSelected)
    }
}
