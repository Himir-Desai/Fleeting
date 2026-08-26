import Core
import DesignSystem
import SwiftUI

/// One row of the inbox: the thought, the control that says what it is, and the actions that
/// apply to it.
///
/// Split out of ``InboxView`` so the list body stays readable, and because a row has enough rules
/// of its own to be worth reading on its own.
struct InboxListRow: View {
    let thought: Thought
    let freshness: Freshness
    let expiresAt: Date?
    let onEdit: (String) -> Void
    let onCorrectKind: (ThoughtKind) -> Void
    let onSnooze: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onComplete: () -> Void
    let onMarkHabitKept: () -> Void
    let onSharpen: () -> Void

    /// The kind control's tap target. 44pt is the smallest a control may be, and it has to grow
    /// with the type size rather than staying a fixed square.
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44

    /// The tinted chip drawn inside that tap target.
    @ScaledMetric(relativeTo: .body) private var chipSize: CGFloat = 34

    var body: some View {
        HStack(spacing: Spacing.snug) {
            kindControl

            NavigationLink {
                ThoughtEditor(thought: thought, onSave: onEdit)
            } label: {
                ThoughtRow(thought: thought, freshness: freshness, expiresAt: expiresAt)
            }
        }
        .listRowInsets(
            EdgeInsets(
                top: 0, leading: Spacing.loose,
                bottom: 0, trailing: Spacing.loose
            )
        )
        .listRowSeparator(.hidden)
        // A card rather than a striped row, and the rail is the freshness read a second time:
        // a column of rails is scannable in a way a column of meters is not.
        .listRowBackground(
            CardSurface(
                rail: FreshnessStyle.tint(for: freshness.value),
                railOpacity: FreshnessStyle.railOpacity(for: freshness.value)
            )
            .padding(.horizontal, Spacing.snug)
            .padding(.vertical, Spacing.tight)
        )
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            typeAction
            Button(action: onSnooze) {
                Label("Snooze", systemImage: "moon.zzz")
            }
            .tint(Palette.inkMuted)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(Palette.inkMuted)
        }
    }

    /// The kind control for a row: one tap opens it, one more corrects the kind.
    ///
    /// A visible control rather than a long-press, so the correction is discoverable.
    private var kindControl: some View {
        Menu {
            Picker("Kind", selection: kindBinding) {
                ForEach(ThoughtKind.allCases, id: \.self) { kind in
                    Label(KindGlyph.label(for: kind), systemImage: KindGlyph.name(for: kind))
                        .tag(kind)
                }
            }
        } label: {
            Image(systemName: KindGlyph.name(for: thought.kind))
                .font(Typography.caption)
                .foregroundStyle(
                    thought.kind == .unsorted ? Palette.inkMuted : Palette.accentText
                )
                .frame(width: chipSize, height: chipSize)
                .background {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(thought.kind == .unsorted ? Palette.surfaceSunken : Palette.accentSoft)
                }
                .frame(width: controlSize, height: controlSize)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("row.kind")
        .accessibilityLabel("Kind: \(KindGlyph.label(for: thought.kind))")
        .accessibilityHint("Change what this thought is")
    }

    /// A binding that writes a kind correction straight through to the model.
    private var kindBinding: Binding<ThoughtKind> {
        Binding(get: { thought.kind }, set: onCorrectKind)
    }

    /// The action that makes sense for a thought's kind, if any.
    ///
    /// A todo can be completed, a habit can be kept, and an idea can be sharpened. An unsorted
    /// thought has no obvious next step, so it is offered none.
    @ViewBuilder
    private var typeAction: some View {
        switch thought.kind {
        case .todo:
            Button(action: onComplete) {
                Label("Done", systemImage: "checkmark")
            }
            .tint(Palette.accent)
        case .habit:
            Button(action: onMarkHabitKept) {
                Label("Kept", systemImage: "flame")
            }
            .tint(Palette.accent)
        case .idea:
            Button(action: onSharpen) {
                Label("Sharpen", systemImage: "sparkles")
            }
            .tint(Palette.accent)
        case .unsorted:
            EmptyView()
        }
    }
}
