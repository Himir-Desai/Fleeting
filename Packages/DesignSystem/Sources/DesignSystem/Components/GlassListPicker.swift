import SwiftUI

/// A native list menu with the same presentation as the thought-kind filter.
public struct GlassListPicker: View {
    public struct Choice: Identifiable, Equatable {
        public let id: String
        public let name: String
        public let detail: String?

        public init(id: String, name: String, detail: String? = nil) {
            self.id = id
            self.name = name
            self.detail = detail
        }
    }

    @Binding private var selection: String?
    private let choices: [Choice]
    private let unselectedLabel: String
    private let controlSize: CGFloat
    private let identifier: String
    private let onCreate: () -> Void
    private let onEdit: (() -> Void)?
    private let onClose: () -> Void

    public init(
        selection: Binding<String?>, choices: [Choice],
        unselectedLabel: String, identifier: String,
        controlSize: CGFloat = 44, onCreate: @escaping () -> Void,
        onEdit: (() -> Void)? = nil, onClose: @escaping () -> Void = {}
    ) {
        _selection = selection
        self.choices = choices
        self.unselectedLabel = unselectedLabel
        self.controlSize = controlSize
        self.identifier = identifier
        self.onCreate = onCreate
        self.onEdit = onEdit
        self.onClose = onClose
    }

    public var body: some View {
        menu.floatingGlass()
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(selectedName ?? "Lists")
            .accessibilityHint("Choose or create a list")
    }

    private var menu: some View {
        Menu {
            Picker("Lists", selection: Binding(
                get: { selection },
                set: { selection = $0; onClose() }
            )) {
                Text(unselectedLabel).tag(nil as String?)
                    .accessibilityIdentifier("\(identifier).choice.all")
                ForEach(choices) { choice in
                    Text(choice.detail.map { "\(choice.name) · \($0)" } ?? choice.name)
                        .tag(Optional(choice.id))
                        .accessibilityIdentifier("\(identifier).choice.\(choice.id)")
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button("Create list", systemImage: "plus", action: onCreate)
                .accessibilityIdentifier("\(identifier).new")
            if let onEdit {
                Button("Edit lists", systemImage: "pencil", action: onEdit)
                    .accessibilityIdentifier("\(identifier).edit")
            }
        } label: {
            Text(compactLabel)
                .font(Typography.body)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(selection == nil ? Palette.inkMuted : Palette.accentText)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, Spacing.regular)
                .frame(width: 96, height: controlSize)
                .contentShape(.rect)
        }
    }

    private var selectedName: String? {
        choices.first { $0.id == selection }?.name
    }

    private var compactLabel: String {
        guard let selectedName else { return "Lists" }
        return selectedName.count > 10 ? String(selectedName.prefix(10)) + "…" : selectedName
    }
}
