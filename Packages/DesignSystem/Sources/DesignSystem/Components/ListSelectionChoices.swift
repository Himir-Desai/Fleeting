import SwiftUI

/// Shared list choices and management actions inside an anchored native popover.
public struct ListSelectionChoices: View {
    private let choices: [GlassListPicker.Choice]
    private let selection: String?
    private let unassignedLabel: String?
    private let onSelect: (String?) -> Void
    private let onAdd: () -> Void
    private let onEdit: () -> Void

    public init(
        choices: [GlassListPicker.Choice], selection: String?, unassignedLabel: String? = nil,
        onSelect: @escaping (String?) -> Void, onAdd: @escaping () -> Void, onEdit: @escaping () -> Void
    ) {
        self.choices = choices
        self.selection = selection
        self.unassignedLabel = unassignedLabel
        self.onSelect = onSelect
        self.onAdd = onAdd
        self.onEdit = onEdit
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let unassignedLabel {
                    choice(unassignedLabel, id: nil)
                    separator
                }
                ForEach(choices) { item in
                    choice(item.name, id: item.id, detail: item.detail)
                    separator
                }
                action("Add List", symbol: "plus", action: onAdd)
                action("Edit Lists", symbol: "pencil", action: onEdit)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(
            width: 280,
            height: min(
                CGFloat(rowCount) * 52 + CGFloat(choices.filter { $0.detail != nil }.count) * 20
                    + CGFloat(choices.count + (unassignedLabel == nil ? 0 : 1)),
                420
            )
        )
        .padding(.vertical, Spacing.snug)
    }

    private var rowCount: Int {
        choices.count + 2 + (unassignedLabel == nil ? 0 : 1)
    }

    private var separator: some View {
        Divider().overlay(Palette.separator).padding(.horizontal, Spacing.inset)
    }

    private func choice(_ name: String, id: String?, detail: String? = nil) -> some View {
        Button { onSelect(id) } label: {
            HStack(spacing: Spacing.regular) {
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    Text(name).font(Typography.body)
                        .foregroundStyle(selection == id ? Palette.accentText : Palette.inkMuted)
                    if let detail {
                        Text(detail).font(Typography.caption).foregroundStyle(Palette.inkMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if selection == id {
                    Image(systemName: "checkmark").foregroundStyle(Palette.accentText)
                }
            }
            .padding(.horizontal, Spacing.inset)
            .frame(minHeight: detail == nil ? 52 : 72)
            .contentShape(.rect)
        }
        .buttonStyle(PressFeedbackStyle())
        .accessibilityLabel(name)
        .accessibilityHint(detail ?? "")
        .accessibilityAddTraits(selection == id ? .isSelected : [])
    }

    private func action(_ name: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(name, systemImage: symbol)
                .font(Typography.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.inset)
                .frame(minHeight: 52)
                .contentShape(.rect)
        }
        .buttonStyle(PressFeedbackStyle())
        .foregroundStyle(Palette.accentText)
    }
}
