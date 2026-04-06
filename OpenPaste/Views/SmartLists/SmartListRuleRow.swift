import SwiftUI

struct SmartListRuleRow: View {
    @Binding var rule: SmartListRule
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Field picker
            Picker("", selection: $rule.field) {
                ForEach(RuleField.allCases, id: \.self) { field in
                    Text(field.displayName).tag(field)
                }
            }
            .frame(width: 120)

            // Comparison picker
            Picker("", selection: $rule.comparison) {
                ForEach(rule.field.availableComparisons, id: \.self) { comp in
                    Text(comp.displayName).tag(comp)
                }
            }
            .frame(width: 120)
            .onChange(of: rule.field) { _, newField in
                // Reset comparison if not available for new field
                if !newField.availableComparisons.contains(rule.comparison) {
                    rule.comparison = newField.availableComparisons.first ?? .equals
                }
            }

            // Value input (adapts to field type)
            valueInput
                .frame(maxWidth: .infinity)

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var valueInput: some View {
        switch rule.field {
        case .contentType:
            Picker("", selection: $rule.value) {
                ForEach(ContentType.allCases, id: \.rawValue) { type in
                    Text(type.rawValue.capitalized).tag(type.rawValue)
                }
            }
        case .createdDate:
            Picker("", selection: $rule.value) {
                Text("Today").tag("today")
                Text("Yesterday").tag("yesterday")
                Text("Last 24 hours").tag("-24h")
                Text("Last 7 days").tag("-7d")
                Text("Last 30 days").tag("-30d")
            }
        case .pinned, .starred, .isSensitive:
            // No value needed for boolean fields
            Text(rule.comparison == .isTrue ? "Yes" : "No")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
        case .contentLength:
            HStack(spacing: 4) {
                TextField("Size", text: $rule.value)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("chars")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        default:
            TextField("Value", text: $rule.value)
                .textFieldStyle(.roundedBorder)
        }
    }
}
