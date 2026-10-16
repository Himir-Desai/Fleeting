import Core
import DesignSystem
import SwiftUI

/// The opened thought: everything you can do to it in one pushed screen — edit the words, change
/// its type, set how long it lasts, enhance it, keep it, snooze, archive or delete.
///
/// Absorbs the Sharpen entry point (its "Enhance" action), which the app layer routes on to the
/// Sharpen screen, because a feature may not import another feature (ADR-0012).
public struct ThoughtDetailView: View {
    @State private var model: ThoughtDetailModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditing: Bool
    @State private var isChoosingList = false

    private let onEnhance: () -> Void
    private let onAddList: (@escaping (ThoughtList) -> Void) -> Void
    private let onEditLists: () -> Void

    /// Creates the detail.
    /// - Parameters:
    ///   - model: State and actions for the opened thought.
    ///   - onEnhance: Called when the user asks to develop the thought further; the app layer
    ///     opens the Sharpen flow.
    public init(
        model: ThoughtDetailModel, onEnhance: @escaping () -> Void,
        onAddList: @escaping (@escaping (ThoughtList) -> Void) -> Void = { _ in },
        onEditLists: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: model)
        self.onEnhance = onEnhance
        self.onAddList = onAddList
        self.onEditLists = onEditLists
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                if let error = model.lastError {
                    Text(error).font(Typography.caption).foregroundStyle(Palette.fading)
                        .accessibilityIdentifier("detail.error")
                }
                textWell
                Card {
                    VStack(alignment: .leading, spacing: Spacing.loose) {
                        typeSection.disabled(!model.canEdit)
                        Divider().overlay(Palette.separator)
                        listSection
                    }
                }
                if let kindAction, model.thought.kind == .habit {
                    KindActionButton(
                        label: kindAction.label,
                        symbol: kindAction.symbol,
                        isHabit: model.thought.kind == .habit
                    ) {
                        Task {
                            if await kindAction.perform() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(model.isReadOnly)
                }
                if model.canUndoHabitKept, let streak = model.thought.streak {
                    StreakSection(streak: streak, cadence: model.thought.cadence) {
                        Task { await model.undoHabitKept() }
                    }
                    .disabled(model.isReadOnly)
                }
                // Only a habit has a rhythm, and it sits with the streak because the two are the
                // same subject: how often, and how well it has gone (ADR-0048).
                if model.thought.kind == .habit {
                    CadenceSection(
                        cadence: model.thought.cadence,
                        isInferred: model.cadenceIsInferred,
                        onChoose: { cadence in
                            Task { await model.chooseCadence(cadence) }
                        }
                    )
                    .disabled(!model.canEdit)
                }
                if model.thought.sharing == nil {
                    Card { expirySection }.disabled(!model.canEdit)
                } else {
                    Text(model.thought
                        .canEditContent ? "Shared thoughts are archived manually." :
                        "View-only shared list. Your habit progress and hiding stay personal.")
                        .font(Typography.caption).foregroundStyle(Palette.inkMuted)
                }
                actions
            }
            .padding(Spacing.loose)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.surface)
        .keyboardDismissControl(isFocused: isEditing, identifier: "detail.dismissKeyboard") {
            isEditing = false
        }
        .pageHeading("Thought")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await model.saveText(); isEditing = false }
                }
                .disabled(!model.canSaveText)
                .accessibilityIdentifier("detail.save")
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await model.observeChanges() }
        .onChange(of: model.isDeleted) { _, deleted in
            if deleted {
                dismiss()
            }
        }
        // Text is committed when leaving, so an edit is never lost by tapping back.
        .onDisappear { Task { await model.saveText() } }
    }

    private var listSection: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            SectionLabel("List")
            Button { isChoosingList = true } label: {
                Label(
                    model.lists.first { $0.id == model.thought.listID }?.name ?? "No list",
                    systemImage: "list.bullet"
                )
                .font(Typography.body)
                .frame(minHeight: 44)
            }
            .buttonStyle(PressFeedbackStyle())
            .foregroundStyle(Palette.accentText)
            .accessibilityIdentifier("detail.list")
            .disabled(!model.canEdit || model.thought.sharing != nil)
            .popover(isPresented: $isChoosingList) {
                ListSelectionChoices(
                    choices: model.lists.map { .init(
                        id: $0.id.uuidString,
                        name: $0.name,
                        detail: $0.sharing?.summary
                    ) },
                    selection: model.thought.listID?.uuidString, unassignedLabel: "No list",
                    onSelect: { id in
                        isChoosingList = false
                        Task { await model.moveToList(id.flatMap(UUID.init(uuidString:))) }
                    }, onAdd: {
                        isChoosingList = false
                        onAddList { list in Task { await model.moveToList(list.id) } }
                    }, onEdit: {
                        isChoosingList = false
                        onEditLists()
                    }
                )
                .accessibilityIdentifier("detail.listChoices")
                .presentationCompactAdaptation(.popover)
            }
            if let error = model.listError {
                Text(error).font(Typography.caption).foregroundStyle(Palette.fading)
            }
        }
    }

    /// The editable raw text, in the same recessed well as capture.
    private var textWell: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            TextField("", text: $model.draft, axis: .vertical)
                .font(Typography.capture)
                .foregroundStyle(Palette.ink)
                .tint(Palette.accentText)
                .focused($isEditing)
                .disabled(!model.canEdit)
                .accessibilityLabel("Thought text")
                .accessibilityIdentifier("detail.text")
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(Spacing.inset)
                .background {
                    RoundedRectangle(cornerRadius: Radius.well, style: .continuous)
                        .fill(Palette.surfaceSunken)
                }
        }
    }

    /// The type selector: four chips, the current kind filled.
    private var typeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.regular) {
            SectionLabel("Type")
            ThoughtKindPicker(selection: model.thought.kind, identifier: "detail.type") { kind in
                Task { await model.chooseKind(kind) }
            }
        }
    }

    /// A kind's primary action: its label, icon, and what it does.
    private struct KindAction {
        let label: String
        let symbol: String
        let perform: () async -> Bool
    }

    /// The kind-specific action for the current thought, if any.
    private var kindAction: KindAction? {
        switch model.thought.kind {
        case .todo: nil
        case .habit:
            KindAction(label: "Continue streak", symbol: "leaf") { await model.markHabitKept() }
        case .idea, .unsorted: nil
        }
    }

    /// How long the thought lasts: a switch to a custom lifetime, then the wheels.
    private var expirySection: some View {
        VStack(alignment: .leading, spacing: Spacing.regular) {
            Toggle(isOn: expiryEnabledBinding) {
                Text("Custom expiry")
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink)
            }
            .tint(Palette.accent)
            .accessibilityIdentifier("detail.expiry.toggle")

            if model.usesCustomExpiration {
                VStack(alignment: .leading, spacing: Spacing.snug) {
                    SectionLabel("Expires in")
                    ExpiryWheels(count: expiryCountBinding, unit: expiryUnitBinding)
                }
            }
        }
    }

    /// Enhance, snooze, archive and delete, as labelled round chips.
    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Spacing.regular) { actionChoices }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.loose) {
                actionChoices
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var actionChoices: some View {
        if model.thought.kind == .todo {
            actionButton(symbol: "checkmark.circle", label: "Mark done", tint: Palette.accentText) {
                Task {
                    if await model.complete() {
                        dismiss()
                    }
                }
            }
            .disabled(!model.canEdit)
        }
        if model.thought.canEditContent || model.isReadOnly {
            actionButton(symbol: "sparkles", label: "Enhance", tint: Palette.accentText) { onEnhance() }
                .disabled(!model.canEdit)
        }
        actionButton(symbol: "moon.zzz", label: "Snooze", tint: Palette.accentText) {
            Task {
                if await model.snooze(forDays: 7) {
                    dismiss()
                }
            }
        }
        .disabled(model.isReadOnly)
        if model.thought.canEditContent || model.isReadOnly {
            actionButton(
                symbol: model.isReadOnly ? "arrow.uturn.backward" : "archivebox",
                label: model.isReadOnly
                    ? (model.thought.isCompleted ? "Mark as not done" : "Unarchive") : "Archive",
                tint: model.isReadOnly ? Palette.accentText : Palette.inkMuted,
                identifier: "detail.action.archive"
            ) {
                Task {
                    let succeeded: Bool = if model.isReadOnly {
                        await model.restore()
                    } else {
                        await model.archive()
                    }
                    if succeeded {
                        dismiss()
                    }
                }
            }
            .disabled(model.isReadOnly ? !model.canRestore : !model.canEdit)
            actionButton(symbol: "trash", label: "Delete", tint: Palette.fading) {
                Task {
                    if await model.delete() {
                        dismiss()
                    }
                }
            }
            .disabled(!model.canEdit)
        }
    }

    /// One labelled round action chip.
    private func actionButton(
        symbol: String,
        label: String,
        tint: Color,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        RoundIconButton(symbol: symbol, label: label, tint: tint, showsLabel: true, action: action)
            .accessibilityIdentifier(identifier ?? "detail.action.\(label.lowercased())")
    }

    /// The custom-expiry toggle, which applies or clears the override as it flips.
    private var expiryEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.usesCustomExpiration },
            set: { model.usesCustomExpiration = $0; Task { await model.applyExpiry() } }
        )
    }

    /// The number wheel, applying the change as it spins.
    private var expiryCountBinding: Binding<Int> {
        Binding(
            get: { model.expirationCount },
            set: { model.expirationCount = $0; Task { await model.applyExpiry() } }
        )
    }

    /// The unit wheel, applying the change as it spins.
    private var expiryUnitBinding: Binding<ExpirationUnit> {
        Binding(
            get: { model.expirationUnit },
            set: { model.expirationUnit = $0; Task { await model.applyExpiry() } }
        )
    }
}
