import SwiftUI

struct SmartListEditorView: View {
    let smartList: SmartList?
    let onSave: (SmartList) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var icon: String
    @State private var color: String
    @State private var matchMode: MatchMode
    @State private var sortOrder: SmartListSortOrder
    @State private var rules: [SmartListRule]
    @State private var matchCount: Int?

    private let isEditing: Bool

    init(smartList: SmartList?, onSave: @escaping (SmartList) -> Void, onCancel: @escaping () -> Void) {
        self.smartList = smartList
        self.onSave = onSave
        self.onCancel = onCancel
        self.isEditing = smartList != nil

        let sl = smartList ?? SmartList(
            name: "",
            icon: "list.bullet",
            color: "#007AFF",
            rules: [SmartListRule(field: .textContains, comparison: .contains, value: "")],
            isBuiltIn: false,
            position: 0
        )
        _name = State(initialValue: sl.name)
        _icon = State(initialValue: sl.icon)
        _color = State(initialValue: sl.color)
        _matchMode = State(initialValue: sl.matchMode)
        _sortOrder = State(initialValue: sl.sortOrder)
        _rules = State(initialValue: sl.rules)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Smart List" : "New Smart List")
                    .font(.headline)
                Spacer()
                if let matchCount {
                    Text("\(matchCount) items match")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Name + Icon + Color
                    nameSection

                    Divider()

                    // Match mode
                    matchModeSection

                    Divider()

                    // Rules
                    rulesSection

                    Divider()

                    // Sort order
                    sortSection
                }
                .padding()
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Create") {
                    saveSmartList()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || rules.isEmpty)
            }
            .padding()
        }
        .frame(width: 520, height: 480)
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Details")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: DS.Spacing.md) {
                // Icon picker
                iconPicker
                    .frame(width: 36, height: 36)

                TextField("Smart List Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                // Color picker
                colorPicker
            }
        }
    }

    private var iconPicker: some View {
        Menu {
            ForEach(Self.iconOptions, id: \.self) { iconName in
                Button {
                    icon = iconName
                } label: {
                    Label(iconName, systemImage: iconName)
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: color))
                .frame(width: 36, height: 36)
                .background(Color(hex: color).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .menuStyle(.borderlessButton)
    }

    private var colorPicker: some View {
        Menu {
            ForEach(Self.colorOptions, id: \.hex) { option in
                Button {
                    color = option.hex
                } label: {
                    Label(option.name, systemImage: "circle.fill")
                }
            }
        } label: {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(.quaternary, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 30)
    }

    private var matchModeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Match Mode")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("", selection: $matchMode) {
                Text("Match ALL rules (AND)").tag(MatchMode.all)
                Text("Match ANY rule (OR)").tag(MatchMode.any)
            }
            .pickerStyle(.segmented)
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Rules")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    rules.append(SmartListRule(field: .textContains, comparison: .contains, value: ""))
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "plus")
                        Text("Add Rule")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }

            if rules.isEmpty {
                Text("Add at least one rule")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DS.Spacing.md)
            } else {
                ForEach(rules.indices, id: \.self) { index in
                    SmartListRuleRow(
                        rule: $rules[index],
                        onDelete: {
                            rules.remove(at: index)
                        }
                    )
                }
            }
        }
    }

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Sort Order")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("", selection: $sortOrder) {
                Text("Newest First").tag(SmartListSortOrder.newestFirst)
                Text("Oldest First").tag(SmartListSortOrder.oldestFirst)
                Text("Alphabetical").tag(SmartListSortOrder.alphabetical)
                Text("Most Used").tag(SmartListSortOrder.mostUsed)
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Save

    private func saveSmartList() {
        var result: SmartList
        if var existing = smartList {
            existing.name = name.trimmingCharacters(in: .whitespaces)
            existing.icon = icon
            existing.color = color
            existing.matchMode = matchMode
            existing.sortOrder = sortOrder
            existing.rules = rules
            existing.modifiedAt = Date()
            result = existing
        } else {
            result = SmartList(
                name: name.trimmingCharacters(in: .whitespaces),
                icon: icon,
                color: color,
                rules: rules,
                isBuiltIn: false,
                position: 0
            )
            result.matchMode = matchMode
            result.sortOrder = sortOrder
        }
        onSave(result)
    }

    // MARK: - Options

    static let iconOptions: [String] = [
        "list.bullet", "calendar", "photo", "link",
        "chevron.left.forwardslash.chevron.right", "lock.shield",
        "doc.text", "star", "pin", "tag",
        "app", "globe", "terminal", "key",
        "number", "textformat", "clock",
    ]

    static let colorOptions: [(name: String, hex: String)] = [
        ("Blue", "#007AFF"),
        ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55"),
        ("Red", "#FF3B30"),
        ("Orange", "#FF9500"),
        ("Yellow", "#FFCC00"),
        ("Green", "#34C759"),
        ("Teal", "#5AC8FA"),
        ("Indigo", "#5856D6"),
        ("Gray", "#8E8E93"),
    ]
}
