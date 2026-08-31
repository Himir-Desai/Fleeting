import Core
import DesignSystem
import SwiftUI

/// One row in the Archived filter: the thought's words and when it was captured, with restore and
/// permanent delete as swipes.
///
/// Archived thoughts no longer decay, so there is no freshness weight, no inline keep action and
/// nothing to open — the only moves are bringing it back or destroying it.
struct ArchivedListRow: View {
    let thought: Thought
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            Text(thought.body)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(3)
            Text("captured \(thought.capturedAt, format: .relative(presentation: .named))")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkMuted)
        }
        .padding(.vertical, Spacing.snug)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .listRowInsets(
            EdgeInsets(top: 0, leading: Spacing.loose, bottom: 0, trailing: Spacing.loose)
        )
        .listRowSeparator(.hidden)
        .listRowBackground(
            CardSurface(elevation: .flat)
                .padding(.horizontal, Spacing.snug)
                .padding(.vertical, Spacing.tight)
        )
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onRestore) {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(Palette.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
