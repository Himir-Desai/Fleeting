import Core
import DesignSystem
import SwiftUI

/// Shared list details for creation and editing in a native bottom sheet.
public struct ThoughtListEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var model: InboxModel
    @State private var draft: ThoughtList
    @State private var isSaving = false
    @State private var isSharing = false
    private let sharingService: (any ListSharingService)?
    private enum Field: Hashable { case name, description }
    @FocusState private var focusedField: Field?
    private let isNew: Bool
    private let selectOnCreate: Bool
    private let onChange: () -> Void
    private let onSaved: (ThoughtList) -> Void

    public init(
        list: ThoughtList, isNew: Bool, model: InboxModel, selectOnCreate: Bool = true,
        sharingService: (any ListSharingService)? = nil,
        onChange: @escaping () -> Void, onSaved: @escaping (ThoughtList) -> Void = { _ in }
    ) {
        _draft = State(initialValue: list)
        self.sharingService = sharingService
        self.isNew = isNew
        self.selectOnCreate = selectOnCreate
        self.model = model
        self.onChange = onChange
        self.onSaved = onSaved
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                section("Name") {
                    TextField("List name", text: $draft.name)
                        .focused($focusedField, equals: .name)
                        .disabled(draft.sharing?.canEdit == false)
                        .textContentType(.none)
                        .submitLabel(.done)
                        .accessibilityIdentifier("lists.name")
                }
                section("Description", footer: "Describe the topics and thoughts that belong here.") {
                    TextField("What belongs in this list?", text: $draft.description, axis: .vertical)
                        .focused($focusedField, equals: .description)
                        .disabled(draft.sharing?.canEdit == false)
                        .lineLimit(3 ... 6)
                        .accessibilityLabel("List description")
                        .accessibilityIdentifier("lists.description")
                }
                section(
                    "Default thought type",
                    footer:
                    "New thoughts start with this type. Unsorted lets the app choose after capture."
                ) {
                    ThoughtKindPicker(selection: draft.defaultKind, identifier: "lists.defaultType") { kind in
                        draft.defaultKind = kind
                    }
                    .disabled(draft.sharing?.canEdit == false)
                }
                if let error = validationError ?? model.listError {
                    Text(error)
                        .font(Typography.subtitle)
                        .foregroundStyle(Palette.fading)
                        .accessibilityIdentifier("lists.error")
                }
                if !isNew, !draft.isBuiltIn, let sharingService {
                    ThoughtListSharingControls(
                        list: draft, model: model, service: sharingService,
                        isSharing: $isSharing, isSaving: isSaving,
                        hasInvalidName: normalizedName.isEmpty || validationError != nil,
                        onChange: onChange
                    )
                }
                if !isNew, !draft.isBuiltIn, draft.sharing == nil {
                    VStack(alignment: .leading, spacing: Spacing.snug) {
                        RoundIconButton(
                            symbol: "trash",
                            label: "Delete list",
                            tint: Palette.fading,
                            showsLabel: true,
                            role: .destructive
                        ) {
                            isSaving = true
                            Task {
                                if await model.deleteList(draft) {
                                    onChange()
                                    dismiss()
                                }
                                isSaving = false
                            }
                        }
                        .disabled(isSaving)
                        .accessibilityIdentifier("lists.delete")
                        Text("Its thoughts stay in All thoughts.")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.inkMuted)
                    }
                }
            }
            .padding(Spacing.loose)
        }
        .font(Typography.body)
        .foregroundStyle(Palette.ink)
        .background(Palette.surface)
        .navigationTitle("")
        .accessibilityIdentifier("lists.editor")
        .keyboardDismissControl(isFocused: focusedField != nil, identifier: "lists.dismissKeyboard") {
            focusedField = nil
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close list editor", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Close list editor")
                    .disabled(isSaving)
                    .accessibilityIdentifier("lists.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Create" : "Save", action: save)
                    .disabled(isSaving || isSharing || draft.isBuiltIn || draft.sharing?
                        .canEdit == false || normalizedName.isEmpty || validationError != nil)
                    .accessibilityIdentifier("lists.save")
            }
        }
        .interactiveDismissDisabled(isSaving)
        .task { model.clearListError(); await model.load() }
        .onChange(of: model.lists) { _, lists in
            if let current = lists.first(where: { $0.id == draft.id }) {
                draft.sharing = current.sharing
            }
        }
        .onChange(of: draft) { _, _ in model.clearListError() }
    }

    private var normalizedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validationError: String? {
        guard !normalizedName.isEmpty else { return nil }
        if draft.sharing != nil {
            return normalizedName.localizedCaseInsensitiveCompare("Plan") == .orderedSame
                ? "Plan is reserved for your personal tasks." : nil
        }
        return model.lists.contains {
            $0.id != draft.id && ($0.sharing == nil || $0.sharing?.isOwner == true)
                && $0.name.localizedCaseInsensitiveCompare(normalizedName) == .orderedSame
        } ? "A list with this name already exists." : nil
    }

    private func section(
        _ title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.regular) {
            SectionLabel(title)
            Card(content: content)
            if let footer {
                Text(footer)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
            }
        }
    }

    private func save() {
        guard !isSaving, !normalizedName.isEmpty, validationError == nil, !draft.isBuiltIn else { return }
        var submitted = draft
        submitted.name = normalizedName
        submitted.description = submitted.description.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        Task {
            if await model.saveList(submitted, selecting: isNew && selectOnCreate) {
                onChange()
                onSaved(submitted)
                dismiss()
            }
            isSaving = false
        }
    }
}
