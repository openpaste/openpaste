import SwiftUI

struct PinboardTabBar: View {
    var collectionViewModel: CollectionViewModel?
    var smartListViewModel: SmartListViewModel?
    @Binding var selectedCollectionId: UUID?
    @Binding var selectedSmartListId: UUID?
    var onAddCollection: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // Clipboard History tab
                    PinboardTab(
                        name: "Clipboard History",
                        color: .accentColor,
                        isSelected: selectedCollectionId == nil && selectedSmartListId == nil,
                        onTap: {
                            selectedCollectionId = nil
                            selectedSmartListId = nil
                        }
                    )

                    // Smart List tabs
                    if let slvm = smartListViewModel, !slvm.smartLists.isEmpty {
                        Divider()
                            .frame(height: 16)
                            .opacity(0.3)

                        ForEach(slvm.smartLists) { smartList in
                            PinboardTab(
                                name: smartList.name,
                                icon: smartList.icon,
                                color: Color(hex: smartList.color),
                                isSelected: selectedSmartListId == smartList.id,
                                count: slvm.matchCounts[smartList.id],
                                onTap: { selectedSmartListId = smartList.id }
                            )
                        }
                    }

                    // Collection tabs
                    if let cvm = collectionViewModel, !cvm.collections.isEmpty {
                        Divider()
                            .frame(height: 16)
                            .opacity(0.3)

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
    var icon: String?
    let color: Color
    let isSelected: Bool
    var count: Int?
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(color)
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(nsColor: .separatorColor).opacity(0.2))
                        .clipShape(Capsule())
                }
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
