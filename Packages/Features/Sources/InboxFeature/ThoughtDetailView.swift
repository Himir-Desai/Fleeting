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

    private let onEnhance: () -> Void

    /// The diameter of a round control, grown with the type size to stay a 44pt target.
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 52

    /// Creates the detail.
    /// - Parameters:
    ///   - model: State and actions for the opened thought.
    ///   - onEnhance: Called when the user asks to develop the thought further; the app layer
    ///     opens the Sharpen flow.
    public init(model: ThoughtDetailModel, onEnhance: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.onEnhance = onEnhance
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                textWell
                typeSection
                if kindAction != nil {
                    kindActionButton
                }
                expirySection
                actions
            }
            .padding(Spacing.loose)
        }
        .background(Palette.surface)
        .navigationTitle("Thought")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            // Text is committed when leaving, so an edit is never lost by tapping back.
            .onDisappear { Task { await model.saveText() } }
    }

    /// The editable raw text, in the same recessed well as capture.
    private var textWell: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            SectionLabel("Thought")
            TextField("", text: $model.draft, axis: .vertical)
                .font(Typography.capture)
                .foregroundStyle(Palette.ink)
                .tint(Palette.accentText)
                .focused($isEditing)
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
            HStack(spacing: Spacing.snug) {
                ForEach(ThoughtKind.allCases, id: \.self) { kind in
                    typeChip(kind)
                }
            }
        }
    }

    /// One selectable type chip.
    private func typeChip(_ kind: ThoughtKind) -> some View {
        let isSelected = model.thought.kind == kind
        return Button {
            Task { await model.chooseKind(kind) }
        } label: {
            Image(systemName: KindGlyph.name(for: kind))
                .font(Typography.body)
                .foregroundStyle(isSelected ? Palette.raised : Palette.inkMuted)
                .frame(width: controlSize, height: controlSize)
                .background { Circle().fill(isSelected ? Palette.accent : Palette.surfaceSunken) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(KindGlyph.label(for: kind))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The primary kind action — mark a to-do done, or keep a habit's streak — if the kind has one.
    private var kindActionButton: some View {
        Button {
            Task {
                await kindAction?.perform()
                dismiss()
            }
        } label: {
            Label(kindAction?.label ?? "", systemImage: kindAction?.symbol ?? "")
                .font(Typography.title)
                .foregroundStyle(Palette.raised)
                .padding(.horizontal, Spacing.loose)
                .padding(.vertical, Spacing.regular)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(Palette.accent)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.kindAction")
    }

    /// A kind's primary action: its label, icon, and what it does.
    private struct KindAction {
        let label: String
        let symbol: String
        let perform: () async -> Void
    }

    /// The kind-specific action for the current thought, if any.
    private var kindAction: KindAction? {
        switch model.thought.kind {
        case .todo: KindAction(label: "Mark done", symbol: "checkmark") { await model.complete() }
        case .habit:
            KindAction(label: "Continue streak", symbol: "flame") { await model.markHabitKept() }
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
        HStack(alignment: .top, spacing: Spacing.regular) {
            actionButton(symbol: "sparkles", label: "Enhance", tint: Palette.accentText) {
                onEnhance()
            }
            actionButton(symbol: "moon.zzz", label: "Snooze", tint: Palette.accentText) {
                Task {
                    await model.snooze(forDays: 7)
                    dismiss()
                }
            }
            actionButton(symbol: "archivebox", label: "Archive", tint: Palette.inkMuted) {
                Task {
                    await model.archive()
                    dismiss()
                }
            }
            actionButton(symbol: "trash", label: "Delete", tint: Palette.fading) {
                Task {
                    await model.delete()
                    dismiss()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// One labelled round action chip.
    private func actionButton(
        symbol: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.snug) {
                Image(systemName: symbol)
                    .font(Typography.title)
                    .foregroundStyle(tint)
                    .frame(width: controlSize, height: controlSize)
                    .background { Circle().fill(Palette.surfaceSunken) }
                Text(label)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.action.\(label.lowercased())")
        .accessibilityLabel(label)
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
