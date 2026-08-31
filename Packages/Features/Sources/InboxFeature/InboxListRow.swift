import Core
import DesignSystem
import SwiftUI

/// One row of the inbox: a kind glyph, the thought, and — for a to-do or habit — a single inline
/// button to act without opening. Tapping the row opens the thought; delete and archive are
/// swipes; snooze is a swipe too.
struct InboxListRow: View {
    let thought: Thought
    let freshness: Freshness
    let expiresAt: Date?
    let onOpen: () -> Void
    let onSnooze: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onComplete: () -> Void
    let onMarkHabitKept: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    /// A round control's tap target. 44pt is the smallest a control may be, and it grows with the
    /// type size rather than staying a fixed square.
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44

    /// The glyph chip drawn inside the leading tap target.
    @ScaledMetric(relativeTo: .body) private var chipSize: CGFloat = 34

    var body: some View {
        HStack(spacing: Spacing.regular) {
            Button(action: onOpen) {
                HStack(spacing: Spacing.snug) {
                    kindGlyph
                    ThoughtRow(thought: thought, freshness: freshness, expiresAt: expiresAt)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("row.open")
            .accessibilityHint("Opens this thought")

            inlineAction
        }
        // The whole row fades with its freshness — glyph, words and inline action together — so a
        // fading thought's button is as quiet as its text. Suppressed under increased contrast.
        .opacity(FreshnessStyle.opacity(for: freshness.value, increasedContrast: contrast == .increased))
        .motion(Motion.decay, value: freshness.value)
        .listRowInsets(
            EdgeInsets(top: 0, leading: Spacing.loose, bottom: 0, trailing: Spacing.loose)
        )
        .listRowSeparator(.hidden)
        // A plain card — freshness is the text's weight now, so there is no rail to draw.
        .listRowBackground(
            CardSurface()
                .padding(.horizontal, Spacing.snug)
                .padding(.vertical, Spacing.tight)
        )
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
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

    /// The leading glyph saying what kind the thought is. An indicator, not a control — changing
    /// the kind lives inside the opened thought.
    private var kindGlyph: some View {
        Image(systemName: KindGlyph.name(for: thought.kind))
            .font(Typography.caption)
            .foregroundStyle(thought.kind == .unsorted ? Palette.inkMuted : Palette.accentText)
            .frame(width: chipSize, height: chipSize)
            .background {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(thought.kind == .unsorted ? Palette.surfaceSunken : Palette.accentSoft)
            }
            .frame(width: controlSize, height: controlSize)
            // An indicator, not a control (ADR-0027) — but still the one place the list says
            // what a thought was sorted as, so it stays addressable.
            .accessibilityIdentifier("row.kind")
            .accessibilityLabel("Kind: \(KindGlyph.label(for: thought.kind))")
    }

    /// The one inline action a to-do or habit gets — done, or keep the streak — without opening.
    /// Ideas and unsorted thoughts have none; their next step is behind a tap.
    @ViewBuilder
    private var inlineAction: some View {
        switch thought.kind {
        case .todo:
            actionChip(symbol: "checkmark", label: "Mark done", action: onComplete)
        case .habit:
            actionChip(symbol: "flame", label: "Continue streak", action: onMarkHabitKept)
        case .idea, .unsorted:
            EmptyView()
        }
    }

    /// A round accent chip for the inline action, matching the capture screen's save control.
    private func actionChip(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Typography.body)
                .foregroundStyle(Palette.raised)
                .frame(width: controlSize, height: controlSize)
                .background { Circle().fill(Palette.accent) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
