import SwiftUI

struct SmartFilterBar: View {
    @Binding var filters: SearchFilters
    var onChanged: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(TimeRange.allCases) { range in
                    FilterChip(
                        title: range.rawValue,
                        isActive: filters.timeRange == range
                    ) {
                        filters.timeRange = filters.timeRange == range ? nil : range
                        if let tr = filters.timeRange {
                            filters.dateFrom = tr.dateFrom
                        } else {
                            filters.dateFrom = nil
                        }
                        onChanged()
                    }
                }

                FilterChip(
                    title: "Pinned",
                    isActive: filters.pinnedOnly
                ) {
                    filters.pinnedOnly.toggle()
                    onChanged()
                }

                FilterChip(
                    title: "Starred",
                    isActive: filters.starredOnly
                ) {
                    filters.starredOnly.toggle()
                    onChanged()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, DS.Spacing.xs)
        }
    }
}
