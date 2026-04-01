import SwiftUI

struct RelativeTimestamp: View {
    let date: Date

    var body: some View {
        Text(date.relativeFormatted)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
