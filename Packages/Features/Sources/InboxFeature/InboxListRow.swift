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
        // The card carries the freshness: it loses its fill and its lift together, so a thought
        // about to be archived has visually almost rejoined the page (ADR-0035). The rail is the
        // same number read on a second axis, and only asserts itself near the end.
        .listRowBackground(
            CardSurface(
                freshness: freshness.value,
                rail: FreshnessStyle.tint(for: freshness.value),
                railOpacity: FreshnessStyle.railOpacity(for: freshness.value)
            )
            .padding(.horizontal, Spacing.snug)
            .padding(.vertical, Spacing.tight)
            .motion(Motion.decay, value: freshness.value)
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
    ///
    /// Drawn as a bare glyph in muted ink rather than a tinted chip: the accent is reserved for
    /// time and action, and kind is neither (ADR-0041). The rail beside it already carries a
    /// colour, and two tinted decorations side by side made the row's identity compete with its
    /// urgency.
    private var kindGlyph: some View {
        Image(systemName: KindGlyph.name(for: thought.kind))
            .font(Typography.body)
            .foregroundStyle(Palette.inkMuted)
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
            // A sprout, not a flame. A streak is a thing you have grown by tending it; fire is
            // what happens to a thing you neglect (ADR-0042).
            //
            // Unboxed, unlike the to-do's tick: a drawn plant inside a filled circle reads as a
            // sticker applied to the app rather than as part of its language (ADR-0045).
            Button(action: onMarkHabitKept) {
                GrowingSprout(size: 26)
                    .frame(width: controlSize, height: controlSize)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Continue streak")
        case .idea, .unsorted:
            EmptyView()
        }
    }

    /// A round chip for the inline action.
    ///
    /// Tinted rather than filled: a solid accent disc was the loudest thing in the list, louder
    /// than the thoughts it sat beside (ADR-0041).
    private func actionChip(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Typography.body)
                .foregroundStyle(Palette.accentText)
                .frame(width: controlSize, height: controlSize)
                .background { Circle().fill(Palette.accentSoft) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
